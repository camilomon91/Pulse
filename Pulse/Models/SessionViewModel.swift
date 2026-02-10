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
    @Published var profile: Profile?


    func signOut() async {
        await signOutAndReset()
    }

    func checkSession() async {
        for await state in supabase.auth.authStateChanges {

            guard let session = state.session else {
                reset()
                continue
            }

            if session.isExpired {
                reset()
                continue
            }

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

    func refreshProfile() async {
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


    private func signOutAndReset() async {
        do {
            try await supabase.auth.signOut()
        } catch {
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
            profile = nil
            userRole = nil
            needsProfileCompletion = true
        }
    }
}
