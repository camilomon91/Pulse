//
//  Profile.swift
//  Pulse
//
//  Updated to match Supabase schema (profiles.birthdate is DATE, profiles.is_completed column)
//

import Foundation

enum UserRole: String, Codable {
    case attendee
    case organizer
}

struct Profile: Codable, Identifiable {
    let id: UUID
    var fullName: String?
    var birthdate: String?
    var interests: [String]?
    var role: UserRole
    var isCompleted: Bool?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case birthdate
        case interests
        case role
        case isCompleted = "is_completed"
        case createdAt = "created_at"
    }

    var birthdateDate: Date? {
        guard let birthdate else { return nil }
        return DateFormatters.pgDate.date(from: birthdate)
    }
}

enum DateFormatters {
    static let pgDate: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
