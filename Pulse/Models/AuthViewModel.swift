//
//  AuthViewModel.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import Foundation
import Supabase
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signUp(
                email: email,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}

