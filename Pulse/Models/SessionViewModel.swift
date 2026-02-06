//
//  SessionViewModel.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import Foundation
import Supabase
import Combine

@MainActor
class SessionViewModel: ObservableObject {

    @Published var sessionChecked = false
    @Published var isAuthenticated = false
    @Published var needsProfileCompletion = false
    @Published var userRole: UserRole?
    @Published var profile: Profile? // ✅ for Profile tab + routing consistency

    // MARK: - Public API

    /// Public sign out used by the Profile tab.
    func signOut() async {
        await signOutAndReset()
    }

    func checkSession() async {
        for await state in supabase.auth.authStateChanges {

            // No session → logged out
            guard let session = state.session else {
                reset()
                continue
            }

            // Expired session → logged out
            if session.isExpired {
                reset()
                continue
            }

            // Validate the session with the Auth server (prevents ghost session)
            do {
                _ = try await supabase.auth.user()
            } catch {
                await signOutAndReset()
                continue
            }

            isAuthenticated = true
            await fetchProfile(userID: session.user.id)
            sessionChecked = true
        }
    }

    /// Re-fetch profile state without waiting for an auth state change.
    func refreshProfile() async {
        // Validate against the server before trusting locally cached tokens.
        do {
            _ = try await supabase.auth.user()
        } catch {
            await signOutAndReset()
            return
        }

        guard let user = supabase.auth.currentUser else {
            await signOutAndReset()
            return
        }

        isAuthenticated = true
        await fetchProfile(userID: user.id)
        sessionChecked = true
    }

    // MARK: - Private helpers

    /// Signs out (best-effort) and resets local state.
    private func signOutAndReset() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            // Even if sign-out fails, we reset local state to avoid a stuck UI.
        }
        reset()
    }

    private func reset() {
        isAuthenticated = false
        needsProfileCompletion = false
        userRole = nil
        profile = nil
        sessionChecked = true
    }

    /// Fetch the full profile row. If it doesn't exist, we route to Complete Profile.
    private func fetchProfile(userID: UUID) async {
        do {
            let fetched: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value

            profile = fetched
            userRole = fetched.role
            needsProfileCompletion = (fetched.isCompleted != true)

        } catch {
            // Profile doesn't exist yet OR decoding failed
            profile = nil
            userRole = nil
            needsProfileCompletion = true
        }
    }
}
