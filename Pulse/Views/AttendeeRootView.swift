//
//  AttendeeRootView.swift
//  Pulse
//

import SwiftUI

struct AttendeeRootView: View {
    var body: some View {
        TabView {
            ExploreEventsView()
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }

            MyStuffView()
                .tabItem { Label("My Stuff", systemImage: "bag") }

            ProfileTabView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}
