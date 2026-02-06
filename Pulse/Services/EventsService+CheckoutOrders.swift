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

    func fetchOrderItemsWithTicketTypes(orderId: UUID) async throws -> [OrderItemWithTicket] {
        try await supabase
            .from("order_items")
            .select("id,order_id,ticket_type_id,quantity,unit_price_cents,currency,ticket_types(id,name,description,price_cents,currency)")
            .eq("order_id", value: orderId)
            .execute()
            .value
    }
}
