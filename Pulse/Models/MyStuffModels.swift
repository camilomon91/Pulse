import Foundation

struct EventSnippet: Codable, Identifiable {
    let id: UUID
    let title: String
    let startAt: Date
    let city: String?
    let coverUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startAt = "start_at"
        case city
        case coverUrl = "cover_url"
    }
}

struct OrderWithEvent: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let status: String
    let totalCents: Int
    let currency: String
    let createdAt: Date
    let event: EventSnippet

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case totalCents = "total_cents"
        case currency
        case createdAt = "created_at"
        case event = "events"
    }
}

struct RSVPWithEvent: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let status: String
    let createdAt: Date
    let event: EventSnippet

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case createdAt = "created_at"
        case event = "events"
    }
}
