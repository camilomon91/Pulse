import Foundation
import Supabase

extension EventsService {
    func createOrder(eventId: UUID, items: [CheckoutItem]) async throws -> UUID {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arr = json as? [Any] else {
            throw NSError(domain: "Pulse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid items payload"])
        }

        let params: [String: AnyJSON] = [
            "p_event_id": .string(eventId.uuidString),
            "p_items": .array(arr.map { AnyJSON.fromAny($0) })
        ]

        do {
            let orderIdString: String = try await supabase
                .rpc("create_order_with_items", params: params)
                .execute()
                .value

            guard let orderId = UUID(uuidString: orderIdString) else {
                throw NSError(domain: "Pulse", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid order id returned"])
            }
            return orderId
        } catch {
            let orderId: UUID = try await supabase
                .rpc("create_order_with_items", params: params)
                .execute()
                .value
            return orderId
        }
    }

    func fetchMyOrdersWithEvent(limit: Int = 50) async throws -> [OrderWithEvent] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("orders")
            .select("id,event_id,user_id,status,total_cents,currency,created_at,events(id,title,start_at,city,cover_url)")
            .eq("user_id", value: user.id)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }


    func fetchOrganizerOrdersWithEvent(limit: Int = 100) async throws -> [OrderWithEvent] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("orders")
            .select("id,event_id,user_id,status,total_cents,currency,created_at,events!inner(id,title,start_at,city,cover_url)")
            .eq("events.creator_id", value: user.id)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
    func fetchOrderItemsWithTicketTypes(orderId: UUID) async throws -> [OrderItemWithTicket] {
        try await supabase
            .from("order_items")
            .select("id,order_id,ticket_type_id,quantity,unit_price_cents,currency,ticket_types(id,name,description,price_cents,currency)")
            .eq("order_id", value: orderId)
            .execute()
            .value
    }
}

extension EventsService {
    func fetchMyTickets(limit: Int = 100) async throws -> [TicketWithDetails] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("tickets")
            .select("id,event_id,order_id,order_item_id,ticket_type_id,owner_user_id,status,is_active,scan_code,scanned_at,created_at,events(id,title,start_at,city,cover_url),ticket_types(id,name,description,price_cents,currency)")
            .eq("owner_user_id", value: user.id)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchOrganizerOrdersWithDetails(eventId: UUID, limit: Int = 100) async throws -> [OrganizerOrderWithDetails] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("orders")
            .select("id,event_id,user_id,status,total_cents,currency,created_at,events!inner(id,title,start_at,city,cover_url)")
            .eq("event_id", value: eventId)
            .eq("events.creator_id", value: user.id)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchOrganizerTickets(eventId: UUID, limit: Int = 300) async throws -> [TicketWithDetails] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("tickets")
            .select("id,event_id,order_id,order_item_id,ticket_type_id,owner_user_id,status,is_active,scan_code,scanned_at,created_at,events!inner(id,title,start_at,city,cover_url),ticket_types(id,name,description,price_cents,currency)")
            .eq("event_id", value: eventId)
            .eq("events.creator_id", value: user.id)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }




    func fetchOrganizerTicketByScanCode(eventId: UUID, scanCode: String) async throws -> TicketWithDetails? {
        guard let user = supabase.auth.currentUser else { return nil }

        let rows: [TicketWithDetails] = try await supabase
            .from("tickets")
            .select("id,event_id,order_id,order_item_id,ticket_type_id,owner_user_id,status,is_active,scan_code,scanned_at,created_at,events!inner(id,title,start_at,city,cover_url),ticket_types(id,name,description,price_cents,currency)")
            .eq("event_id", value: eventId)
            .eq("scan_code", value: scanCode)
            .eq("events.creator_id", value: user.id)
            .limit(1)
            .execute()
            .value

        return rows.first
    }



    func fetchOrganizerTicketById(eventId: UUID, ticketId: UUID) async throws -> TicketWithDetails? {
        guard let user = supabase.auth.currentUser else { return nil }

        let rows: [TicketWithDetails] = try await supabase
            .from("tickets")
            .select("id,event_id,order_id,order_item_id,ticket_type_id,owner_user_id,status,is_active,scan_code,scanned_at,created_at,events!inner(id,title,start_at,city,cover_url),ticket_types(id,name,description,price_cents,currency)")
            .eq("event_id", value: eventId)
            .eq("id", value: ticketId)
            .eq("events.creator_id", value: user.id)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchProfileSnippet(userId: UUID) async throws -> TicketOwnerSnippet? {
        let rows: [TicketOwnerSnippet] = try await supabase
            .from("profiles")
            .select("id,full_name")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first
    }



    func markTicketScanned(ticketId: UUID, scannedAt: Date) async throws {
        struct TicketScannedUpdate: Encodable {
            let is_active: Bool
            let status: String
            let scanned_at: Date
        }

        try await supabase
            .from("tickets")
            .update(TicketScannedUpdate(is_active: false, status: "scanned", scanned_at: scannedAt))
            .eq("id", value: ticketId)
            .execute()
    }

    func setTicketActive(ticketId: UUID, isActive: Bool) async throws {
        struct TicketActiveUpdate: Encodable {
            let is_active: Bool
        }

        try await supabase
            .from("tickets")
            .update(TicketActiveUpdate(is_active: isActive))
            .eq("id", value: ticketId)
            .execute()
    }
}
