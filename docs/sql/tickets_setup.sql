-- Pulse ticketing support SQL (Supabase/Postgres)
-- Run in Supabase SQL editor.

begin;

-- Needed for gen_random_uuid()
create extension if not exists pgcrypto;

-- 1) Tickets table used by attendee e-ticket + organizer management views
create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  order_item_id uuid references public.order_items(id) on delete set null,
  ticket_type_id uuid references public.ticket_types(id) on delete set null,
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'reserved' check (status in ('reserved', 'paid', 'cancelled', 'refunded', 'scanned')),
  is_active boolean not null default true,
  scan_code text not null unique,
  scanned_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists tickets_owner_user_id_idx on public.tickets(owner_user_id);
create index if not exists tickets_event_id_idx on public.tickets(event_id);
create index if not exists tickets_order_id_idx on public.tickets(order_id);
create index if not exists tickets_ticket_type_id_idx on public.tickets(ticket_type_id);

-- 2) Auto-generate one ticket per purchased quantity when order_items are inserted
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
      md5(gen_random_uuid()::text || clock_timestamp()::text || random()::text || i::text)
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

-- 3) Keep ticket status in sync when order status changes
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

-- 4) RLS for app queries used by attendee + organizer screens
alter table public.tickets enable row level security;

-- attendees can read their own tickets
drop policy if exists "tickets_select_own" on public.tickets;
create policy "tickets_select_own"
on public.tickets
for select
to authenticated
using (owner_user_id = auth.uid());

-- organizers can read tickets for events they created
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

-- organizers can enable/disable tickets for their own events
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

-- Optional but recommended if missing in your DB:
-- organizers can read orders for their events (used by manage/orders screen)
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

-- attendees can read their own orders
drop policy if exists "orders_select_own" on public.orders;
create policy "orders_select_own"
on public.orders
for select
to authenticated
using (user_id = auth.uid());

-- profiles visibility for owner/buyer name embedding
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
