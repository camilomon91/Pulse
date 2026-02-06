import Foundation
import Supabase

extension EventsService {
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
}
