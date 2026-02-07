import SwiftUI
import Combine

@MainActor
final class OrganizerOrdersViewModel: ObservableObject {
    @Published var orders: [OrderWithEvent] = []
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
            orders = try await service.fetchOrganizerOrdersWithEvent(limit: 100)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OrganizerOrdersView: View {
    @StateObject private var vm = OrganizerOrdersViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.orders.isEmpty {
                    ProgressView()
                } else if let msg = vm.errorMessage, vm.orders.isEmpty {
                    ContentUnavailableView(
                        "Couldn't load orders",
                        systemImage: "exclamationmark.triangle",
                        description: Text(msg)
                    )
                } else if vm.orders.isEmpty {
                    ContentUnavailableView(
                        "No orders yet",
                        systemImage: "cart",
                        description: Text("Orders placed for your events will appear here.")
                    )
                } else {
                    List(vm.orders) { order in
                        NavigationLink {
                            OrderDetailView(order: order)
                        } label: {
                            OrganizerOrderRow(
                                title: order.event.title,
                                subtitle: order.event.startAt.formatted(date: .abbreviated, time: .shortened),
                                city: order.event.city,
                                coverUrl: order.event.coverUrl,
                                trailing: "\(order.status.uppercased()) • \(CurrencyFormatter.string(cents: order.totalCents, currency: order.currency))"
                            )
                        }
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Orders")
            .task { await vm.load() }
        }
    }
}

private struct OrganizerOrderRow: View {
    let title: String
    let subtitle: String
    let city: String?
    let coverUrl: String?
    let trailing: String

    var body: some View {
        HStack(spacing: 12) {
            RemoteEventImageView(urlString: coverUrl, width: 56, height: 56, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                if let city, !city.isEmpty {
                    Text(city).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(trailing)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
}
