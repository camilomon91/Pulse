import Foundation

struct TicketOwnerSnippet: Codable {
    let id: UUID
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
    }
}

struct TicketWithDetails: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let orderId: UUID?
    let orderItemId: UUID?
    let ticketTypeId: UUID?
    let ownerUserId: UUID
    let status: String
    let isActive: Bool
    let scanCode: String?
    let scannedAt: Date?
    let createdAt: Date

    let event: EventSnippet?
    let ticketType: TicketTypeEmbedded?
    let owner: TicketOwnerSnippet?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case orderId = "order_id"
        case orderItemId = "order_item_id"
        case ticketTypeId = "ticket_type_id"
        case ownerUserId = "owner_user_id"
        case status
        case isActive = "is_active"
        case scanCode = "scan_code"
        case scannedAt = "scanned_at"
        case createdAt = "created_at"
        case event = "events"
        case ticketType = "ticket_types"
        case owner = "profiles"
    }
}

struct OrganizerOrderWithDetails: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let status: String
    let totalCents: Int
    let currency: String
    let createdAt: Date

    let event: EventSnippet
    let buyer: TicketOwnerSnippet?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case totalCents = "total_cents"
        case currency
        case createdAt = "created_at"
        case event = "events"
        case buyer = "profiles"
    }
}
