import Foundation
import Supabase

extension EventsService {
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

    func createEventReturning(_ insert: EventInsert) async throws -> Event {
        try await supabase
            .from("events")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

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
}
