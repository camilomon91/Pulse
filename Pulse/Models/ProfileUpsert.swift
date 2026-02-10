//
//  ProfileUpsert.swift
//  Pulse
//
//  Updated to match Supabase schema: `birthdate` is DATE, `is_completed` column.
//

import Foundation

struct ProfileUpsert: Encodable {
    let id: UUID
    let full_name: String
    let birthdate: String
    let interests: [String]
    let role: UserRole
    let is_completed: Bool
}
