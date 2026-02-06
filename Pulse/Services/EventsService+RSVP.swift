import Foundation
import Supabase

extension EventsService {
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

    func upsertRSVP(eventId: UUID, status: String = "going") async throws {
        guard let user = supabase.auth.currentUser else { return }

        let payload = RSVPUpsert(event_id: eventId, user_id: user.id, status: status)

        try await supabase
            .from("event_rsvps")
            .upsert(payload)
            .execute()
    }

    func cancelRSVP(eventId: UUID) async throws {
        guard let user = supabase.auth.currentUser else { return }

        try await supabase
            .from("event_rsvps")
            .delete()
            .eq("event_id", value: eventId)
            .eq("user_id", value: user.id)
            .execute()
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
}
