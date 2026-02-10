//
//  CompleteProfileViewModel.swift
//  Pulse
//
//  Updated to match Supabase schema + avoid Postgres DATE encoding issues.
//

import Foundation
import Combine
import Supabase

@MainActor
final class CompleteProfileViewModel: ObservableObject {

    @Published var fullName = ""
    @Published var birthdate = Date()
    @Published var selectedInterests: Set<String> = []
    @Published var role: UserRole = .attendee
    @Published var isLoading = false

    let allInterests = [
        "Music", "Sports", "Tech", "Art",
        "Travel", "Food", "Gaming", "Fitness"
    ]

    func saveProfile() async throws {
        _ = try await supabase.auth.user()

        guard let user = supabase.auth.currentUser else {
            throw NSError(domain: "Pulse", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        isLoading = true
        defer { isLoading = false }

        let birthdateString = DateFormatters.pgDate.string(from: birthdate)

        let payload = ProfileUpsert(
            id: user.id,
            full_name: fullName,
            birthdate: birthdateString,
            interests: Array(selectedInterests),
            role: role,
            is_completed: true
        )

        try await supabase
            .from("profiles")
            .upsert(payload)
            .execute()
    }
}
