//  TicketType.swift
//  Pulse
//
//  Ticketing models for `public.ticket_types` (and the view `public.ticket_types_with_availability`).
//

import Foundation

struct TicketType: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    let creatorId: UUID
    let name: String
    let description: String
    let priceCents: Int
    let currency: String
    let capacity: Int

    /// Total sold / reserved tickets for this ticket type (server-maintained).
    /// Present when selecting from `ticket_types` or `ticket_types_with_availability`.
    let soldCount: Int?

    /// Remaining inventory for this ticket type (computed in the DB view).
    /// Present when selecting from `ticket_types_with_availability`.
    let remaining: Int?

    let isActive: Bool
    let createdAt: Date

    /// Prefer `remaining` if present, otherwise fall back to `capacity - soldCount`.
    var available: Int {
        max(0, remaining ?? (capacity - (soldCount ?? 0)))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case creatorId = "creator_id"
        case name
        case description
        case priceCents = "price_cents"
        case currency
        case capacity
        case soldCount = "sold_count"
        case remaining
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct TicketTypeInsert: Encodable {
    let event_id: UUID
    let creator_id: UUID
    let name: String
    let description: String
    let price_cents: Int
    let currency: String
    let capacity: Int
    let is_active: Bool
}
