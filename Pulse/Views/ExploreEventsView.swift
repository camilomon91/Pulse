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

    private let service = EventsService()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            events = try await service.fetchPublishedUpcoming()
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
                                coverThumb(for: event)

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

    @ViewBuilder
    private func coverThumb(for event: Event) -> some View {
        let size: CGFloat = 64

        if let urlString = event.coverUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 10).frame(width: size, height: size)
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipped()
                        .cornerRadius(10)
                case .failure:
                    RoundedRectangle(cornerRadius: 10).frame(width: size, height: size)
                @unknown default:
                    RoundedRectangle(cornerRadius: 10).frame(width: size, height: size)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: 10).frame(width: size, height: size)
        }
    }
}
