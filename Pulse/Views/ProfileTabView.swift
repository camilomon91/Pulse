//
//  ProfileTabView.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        NavigationStack {
            List {
                if let profile = session.profile {
                    Section("Profile") {
                        row("Name", profile.fullName ?? "—")
                        row("Role", profile.role.rawValue)

                        if let birth = profile.birthdate, !birth.isEmpty {
                            row("Birthdate", birth)
                        }

                        if let interests = profile.interests, !interests.isEmpty {
                            row("Interests", interests.joined(separator: ", "))
                        }

                        row("Completed", (profile.isCompleted == true) ? "Yes" : "No")
                    }
                } else {
                    Section {
                        Text("No profile loaded.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await session.signOut() }
                    } label: {
                        Text("Log out")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}


#Preview {
    ProfileTabView()
}
