import Foundation

struct EventRSVP: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
    }
}

struct RSVPUpsert: Encodable {
    let event_id: UUID
    let user_id: UUID
    let status: String
}
