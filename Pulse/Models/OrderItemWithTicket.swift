//
//  OrderItemWithTicket.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-06.
//

import Foundation

/// Represents one line item in an order, with the embedded ticket type from PostgREST.
/// Query shape:
/// order_items.select("..., ticket_types(...)")
struct OrderItemWithTicket: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let ticketTypeId: UUID
    let quantity: Int
    let unitPriceCents: Int
    let currency: String

    let ticketType: TicketTypeEmbedded?

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case ticketTypeId = "ticket_type_id"
        case quantity
        case unitPriceCents = "unit_price_cents"
        case currency
        case ticketType = "ticket_types"
    }
}

struct TicketTypeEmbedded: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let priceCents: Int
    let currency: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case priceCents = "price_cents"
        case currency
    }
}
