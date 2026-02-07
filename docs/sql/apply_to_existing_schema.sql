-- Patch SQL for an EXISTING Pulse schema (like the one shared by user).
-- Safe to run in Supabase SQL editor.

begin;

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1) Performance indexes used by attendee/organizer queries
-- ------------------------------------------------------------
create index if not exists orders_user_id_idx on public.orders(user_id);
create index if not exists orders_event_id_idx on public.orders(event_id);
create index if not exists order_items_order_id_idx on public.order_items(order_id);
create index if not exists tickets_owner_user_id_idx on public.tickets(owner_user_id);
create index if not exists tickets_event_id_idx on public.tickets(event_id);
create index if not exists tickets_order_id_idx on public.tickets(order_id);
create index if not exists tickets_order_item_id_idx on public.tickets(order_item_id);
create index if not exists tickets_ticket_type_id_idx on public.tickets(ticket_type_id);

-- ------------------------------------------------------------
-- 2) Ticket generation + status sync functions/triggers
-- ------------------------------------------------------------
create or replace function public.generate_scan_code(seed text default null)
returns text
language sql
stable
as $$
  select md5(
    coalesce(seed, '')
    || gen_random_uuid()::text
    || clock_timestamp()::text
    || random()::text
  );
$$;

create or replace function public.create_tickets_for_order_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_event_id uuid;
  i int;
begin
  select o.user_id, o.event_id
    into v_owner_id, v_event_id
  from public.orders o
  where o.id = new.order_id;

  if v_owner_id is null or v_event_id is null then
    raise exception 'Order % not found or missing owner/event', new.order_id;
  end if;

  for i in 1..greatest(new.quantity, 0) loop
    insert into public.tickets (
      event_id,
      order_id,
      order_item_id,
      ticket_type_id,
      owner_user_id,
      status,
      is_active,
      scan_code
    ) values (
      v_event_id,
      new.order_id,
      new.id,
      new.ticket_type_id,
      v_owner_id,
      'reserved',
      true,
      public.generate_scan_code(new.id::text || ':' || i::text)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_create_tickets_for_order_item on public.order_items;
create trigger trg_create_tickets_for_order_item
after insert on public.order_items
for each row
execute function public.create_tickets_for_order_item();

create or replace function public.sync_ticket_status_from_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    update public.tickets t
    set status = case
      when new.status in ('paid', 'completed') then 'paid'
      when new.status in ('cancelled', 'refunded') then new.status
      else t.status
    end,
    is_active = case
      when new.status in ('cancelled', 'refunded') then false
      else t.is_active
    end
    where t.order_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_ticket_status_from_order on public.orders;
create trigger trg_sync_ticket_status_from_order
after update of status on public.orders
for each row
execute function public.sync_ticket_status_from_order();

-- ------------------------------------------------------------
-- 3) Backfill tickets for existing order items (if any missing)
-- ------------------------------------------------------------
insert into public.tickets (
  event_id,
  order_id,
  order_item_id,
  ticket_type_id,
  owner_user_id,
  status,
  is_active,
  scan_code
)
select
  o.event_id,
  oi.order_id,
  oi.id,
  oi.ticket_type_id,
  o.user_id,
  case
    when o.status in ('paid', 'completed') then 'paid'
    when o.status in ('cancelled', 'refunded') then o.status
    else 'reserved'
  end as status,
  case
    when o.status in ('cancelled', 'refunded') then false
    else true
  end as is_active,
  public.generate_scan_code(oi.id::text || ':' || gs.i::text)
from public.order_items oi
join public.orders o on o.id = oi.order_id
join lateral generate_series(1, oi.quantity) as gs(i) on true
left join public.tickets t
  on t.order_item_id = oi.id
 and t.order_id = oi.order_id
 and t.ticket_type_id = oi.ticket_type_id
 and t.owner_user_id = o.user_id
where t.id is null;

-- Keep sold_count in sync with generated/backfilled tickets.
update public.ticket_types tt
set sold_count = coalesce(src.cnt, 0)
from (
  select ticket_type_id, count(*)::int as cnt
  from public.tickets
  where ticket_type_id is not null
    and status not in ('cancelled', 'refunded')
  group by ticket_type_id
) src
where tt.id = src.ticket_type_id;

update public.ticket_types tt
set sold_count = 0
where not exists (
  select 1 from public.tickets t
  where t.ticket_type_id = tt.id
    and t.status not in ('cancelled', 'refunded')
);

-- ------------------------------------------------------------
-- 4) RLS policies required by current app queries
-- ------------------------------------------------------------
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.tickets enable row level security;
alter table public.profiles enable row level security;

-- Orders: attendee own + organizer own events
drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
on public.orders
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "orders_select_organizer_for_own_events" on public.orders;
create policy "orders_select_organizer_for_own_events"
on public.orders
for select
to authenticated
using (
  exists (
    select 1
    from public.events e
    where e.id = orders.event_id
      and e.creator_id = auth.uid()
  )
);

-- Order items: readable by order owner OR event organizer
drop policy if exists "order_items_select_owner_or_organizer" on public.order_items;
create policy "order_items_select_owner_or_organizer"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and (
        o.user_id = auth.uid()
        or exists (
          select 1
          from public.events e
          where e.id = o.event_id
            and e.creator_id = auth.uid()
        )
      )
  )
);

-- Tickets: attendee own + organizer own events + organizer toggle active
drop policy if exists "tickets_select_own" on public.tickets;
create policy "tickets_select_own"
on public.tickets
for select
to authenticated
using (owner_user_id = auth.uid());

drop policy if exists "tickets_select_organizer" on public.tickets;
create policy "tickets_select_organizer"
on public.tickets
for select
to authenticated
using (
  exists (
    select 1
    from public.events e
    where e.id = tickets.event_id
      and e.creator_id = auth.uid()
  )
);

drop policy if exists "tickets_update_organizer_toggle" on public.tickets;
create policy "tickets_update_organizer_toggle"
on public.tickets
for update
to authenticated
using (
  exists (
    select 1
    from public.events e
    where e.id = tickets.event_id
      and e.creator_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.events e
    where e.id = tickets.event_id
      and e.creator_id = auth.uid()
  )
);

-- Profiles: self + organizer can view buyer/owner names for their events
drop policy if exists "profiles_select_self" on public.profiles;
create policy "profiles_select_self"
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists "profiles_select_order_or_ticket_participants" on public.profiles;
create policy "profiles_select_order_or_ticket_participants"
on public.profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    join public.events e on e.id = o.event_id
    where o.user_id = profiles.id
      and e.creator_id = auth.uid()
  )
  or exists (
    select 1
    from public.tickets t
    join public.events e on e.id = t.event_id
    where t.owner_user_id = profiles.id
      and e.creator_id = auth.uid()
  )
);

commit;
