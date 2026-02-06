//
//  MyEventsView.swift
//  Pulse
//

import SwiftUI
import Combine

@MainActor
final class MyEventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: EventsServing

    init(service: EventsServing = EventsService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await service.fetchMyEvents(limit: 50)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func publish(_ event: Event) async {
        do {
            try await service.publishEvent(eventId: event.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MyEventsView: View {
    @StateObject private var vm = MyEventsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.events.isEmpty {
                    ProgressView()
                } else if let msg = vm.errorMessage, vm.events.isEmpty {
                    ContentUnavailableView("Couldn't load your events",
                                          systemImage: "exclamationmark.triangle",
                                          description: Text(msg))
                } else if vm.events.isEmpty {
                    ContentUnavailableView("No events yet",
                                          systemImage: "calendar.badge.plus",
                                          description: Text("Create your first event."))
                } else {
                    List(vm.events) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(event.title).font(.headline)
                                Spacer()
                                Text(event.isPublished ? "Published" : "Draft")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }

                            Text(event.startAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !event.isPublished {
                                Button("Publish") {
                                    Task { await vm.publish(event) }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 6)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("My Events")
            .task { await vm.load() }
        }
    }
}
