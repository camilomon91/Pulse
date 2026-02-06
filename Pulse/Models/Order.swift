//  Order.swift
//  Pulse
//
//  Order models for `public.orders` and `public.order_items`.
//

import Foundation

struct Order: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let status: String
    let totalCents: Int
    let currency: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case totalCents = "total_cents"
        case currency
        case createdAt = "created_at"
    }
}

/// Used by the RPC create_order_with_items
struct CheckoutItem: Encodable {
    let ticket_type_id: UUID
    let quantity: Int
}
