//
//  PulseApp.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import SwiftUI
import Supabase

@main
struct PulseApp: App {

    @StateObject private var session = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if !session.sessionChecked {
                    ProgressView()

                } else if !session.isAuthenticated {
                    AuthView()

                } else if session.needsProfileCompletion {
                    CompleteProfileView {
                        Task {
                            await session.refreshProfile()
                        }
                    }


                } else {
                    switch session.userRole {
                    case .attendee:
                        AttendeeRootView()

                    case .organizer:
                        OrganizerRootView()

                    case nil:
                        ProgressView()
                    }
                }
            }
            .environmentObject(session)
            .task {
                await session.checkSession()
            }
        }
    }
}
