//
//  ExploreEventsView.swift
//  Pulse
//

import SwiftUI
import Combine

@MainActor
final class ExploreEventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: EventsServiceProtocol

    init(service: EventsServiceProtocol = EventsService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await service.fetchPublishedUpcoming(limit: 50)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ExploreEventsView: View {
    @StateObject private var vm = ExploreEventsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.events.isEmpty {
                    ProgressView()

                } else if let msg = vm.errorMessage, vm.events.isEmpty {
                    ContentUnavailableView("Couldn't load events", systemImage: "exclamationmark.triangle", description: Text(msg))

                } else if vm.events.isEmpty {
                    ContentUnavailableView("No upcoming events", systemImage: "calendar")

                } else {
                    List(vm.events) { event in
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            HStack(spacing: 12) {
                                EventImageView(urlString: event.coverUrl, width: 64, height: 64, cornerRadius: 10)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(event.title).font(.headline)
                                    Text(event.startAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if let city = event.city, !city.isEmpty {
                                        Text(city).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Explore")
            .task { await vm.load() }
        }
    }
}
