//
//  EventsService.swift
//  Pulse
//

import Foundation
import Supabase

struct EventsService {

    // MARK: - Events

    func fetchPublishedUpcoming(limit: Int = 50) async throws -> [Event] {
        try await supabase
            .from("events")
            .select()
            .eq("is_published", value: true)
            .gte("start_at", value: Date())
            .order("start_at", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    func fetchMyEvents(limit: Int = 50) async throws -> [Event] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("events")
            .select()
            .eq("creator_id", value: user.id)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func fetchEvent(eventId: UUID) async throws -> Event {
        try await supabase
            .from("events")
            .select()
            .eq("id", value: eventId)
            .single()
            .execute()
            .value
    }

    /// Creates an event and returns the inserted row (so you can use the ID for ticket types / cover upload).
    func createEventReturning(_ insert: EventInsert) async throws -> Event {
        try await supabase
            .from("events")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    /// Backwards-compatible (if you still call createEvent elsewhere).
    func createEvent(_ insert: EventInsert) async throws {
        _ = try await createEventReturning(insert)
    }

    func publishEvent(eventId: UUID) async throws {
        try await supabase
            .from("events")
            .update(["is_published": true])
            .eq("id", value: eventId)
            .execute()
    }

    // MARK: - Cover Images (Supabase Storage)

    /// Uploads a JPEG cover image to Storage and returns a PUBLIC URL string.
    /// Requires Storage policies for bucket `event-covers`.
    func uploadEventCover(eventId: UUID, jpegData: Data) async throws -> String {
        let bucket = supabase.storage.from("event-covers")
        let path = "\(eventId.uuidString).jpg"

        // New SDK signature: upload(_:data:options:)
        try await bucket.upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )

        let url = try bucket.getPublicURL(path: path)
        return url.absoluteString
    }

    func updateEventCoverURL(eventId: UUID, coverURL: String) async throws {
        try await supabase
            .from("events")
            .update(["cover_url": coverURL])
            .eq("id", value: eventId)
            .execute()
    }

    // MARK: - Ticket Types

    func fetchTicketTypes(eventId: UUID) async throws -> [TicketType] {
        try await supabase
            .from("ticket_types_with_availability")
            .select()
            .eq("event_id", value: eventId)
            .eq("is_active", value: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func createTicketTypes(_ inserts: [TicketTypeInsert]) async throws {
        guard !inserts.isEmpty else { return }
        try await supabase
            .from("ticket_types")
            .insert(inserts)
            .execute()
    }

    // MARK: - Checkout (no payments yet)

    /// Calls the Postgres function `create_order_with_items(p_event_id, p_items)` and returns the created order id.
    func createOrder(eventId: UUID, items: [CheckoutItem]) async throws -> UUID {
        // Encode items as JSON for rpc
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

        // Some SDKs decode UUID as String; some as UUID. Handle both.
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

    // MARK: - RSVPs

    /// Returns the current user's RSVP for an event (if any).
    func getMyRSVP(eventId: UUID) async throws -> EventRSVP? {
        guard let user = supabase.auth.currentUser else { return nil }

        let result: [EventRSVP] = try await supabase
            .from("event_rsvps")
            .select()
            .eq("event_id", value: eventId)
            .eq("user_id", value: user.id)
            .limit(1)
            .execute()
            .value

        return result.first
    }

    /// Creates or updates the RSVP (requires a UNIQUE(event_id, user_id) constraint).
    func upsertRSVP(eventId: UUID, status: String = "going") async throws {
        guard let user = supabase.auth.currentUser else { return }

        let payload = RSVPUpsert(event_id: eventId, user_id: user.id, status: status)

        try await supabase
            .from("event_rsvps")
            .upsert(payload)
            .execute()
    }

    /// Removes the RSVP row (effectively "cancel RSVP").
    func cancelRSVP(eventId: UUID) async throws {
        guard let user = supabase.auth.currentUser else { return }

        try await supabase
            .from("event_rsvps")
            .delete()
            .eq("event_id", value: eventId)
            .eq("user_id", value: user.id)
            .execute()
    }

    // MARK: - My Stuff (Orders + RSVPs) + Ticket line items

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

    func fetchMyRSVPsWithEvent(limit: Int = 50) async throws -> [RSVPWithEvent] {
        guard let user = supabase.auth.currentUser else { return [] }

        return try await supabase
            .from("event_rsvps")
            .select("id,event_id,user_id,status,created_at,events(id,title,start_at,city,cover_url)")
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

// MARK: - Helper to build AnyJSON from Foundation types.
// Your Supabase AnyJSON enum doesn't expose numeric cases in this SDK version.
private extension AnyJSON {
    static func fromAny(_ value: Any) -> AnyJSON {
        switch value {
        case let s as String:
            return .string(s)

        case let n as Int:
            return .string(String(n))
        case let n as Int64:
            return .string(String(n))
        case let n as Double:
            return .string(String(n))
        case let n as Float:
            return .string(String(n))

        case let b as Bool:
            return .bool(b)

        case let dict as [String: Any]:
            return .object(dict.mapValues { AnyJSON.fromAny($0) })

        case let arr as [Any]:
            return .array(arr.map { AnyJSON.fromAny($0) })

        case _ as NSNull:
            return .null

        default:
            return .string(String(describing: value))
        }
    }
}
