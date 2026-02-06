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

    // MARK: - Form fields
    @Published var fullName = ""
    @Published var birthdate = Date()
    @Published var selectedInterests: Set<String> = []
    @Published var role: UserRole = .attendee
    @Published var isLoading = false

    // MARK: - Interests
    let allInterests = [
        "Music", "Sports", "Tech", "Art",
        "Travel", "Food", "Gaming", "Fitness"
    ]

    // MARK: - Save profile
    func saveProfile() async throws {
        // Validate against server to avoid "ghost session" issues
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
