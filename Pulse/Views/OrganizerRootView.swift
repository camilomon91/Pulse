//
//  OrganizerRootView.swift
//  Pulse
//

import SwiftUI
import Combine

struct OrganizerRootView: View {
    var body: some View {
        TabView {
            MyEventsView()
                .tabItem { Label("My Events", systemImage: "calendar") }

            CreateEventView()
                .tabItem { Label("Create", systemImage: "plus.circle") }

            ProfileTabView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}

#Preview {
    OrganizerRootView()
}
