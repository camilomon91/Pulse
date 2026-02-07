//  Event.swift
//  Pulse
//
//  Events model matching `public.events` table.
//

import Foundation

struct Event: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let title: String
    let description: String
    let startAt: Date
    let endAt: Date?
    let locationName: String?
    let locationAddress: String?
    let city: String?
    let coverUrl: String?
    let category: String?

    /// Ticketing mode
    let isFree: Bool
    /// Capacity for RSVP-only free events (nil = unlimited)
    let rsvpCapacity: Int?

    let isPublished: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case title
        case description
        case startAt = "start_at"
        case endAt = "end_at"
        case locationName = "location_name"
        case locationAddress = "location_address"
        case city
        case coverUrl = "cover_url"
        case category
        case isFree = "is_free"
        case rsvpCapacity = "rsvp_capacity"
        case isPublished = "is_published"
        case createdAt = "created_at"
    }
}

/// Insert payload (Encodable) for creating events.
struct EventInsert: Encodable {
    let creator_id: UUID
    let title: String
    let description: String
    let start_at: Date
    let end_at: Date?
    let location_name: String?
    let location_address: String?
    let city: String?
    let cover_url: String?
    let category: String?
    let is_free: Bool
    let rsvp_capacity: Int?
    let is_published: Bool
}

struct EventUpdate: Encodable {
    let title: String
    let description: String
    let start_at: Date
    let end_at: Date?
    let location_name: String?
    let city: String?
    let is_published: Bool
}
