import SwiftUI
import Combine
import Foundation
import Supabase

// MARK: - ViewModel

@MainActor
final class MyStuffViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case orders = "Orders"
        case rsvps = "RSVPs"
        var id: String { rawValue }
    }

    @Published var segment: Segment = .orders
    @Published var orders: [OrderWithEvent] = []
    @Published var rsvps: [RSVPWithEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = EventsService()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let o = service.fetchMyOrdersWithEvent()
            async let r = service.fetchMyRSVPsWithEvent()
            orders = try await o
            rsvps = try await r
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Views

struct MyStuffView: View {
    @StateObject private var vm = MyStuffViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $vm.segment) {
                    ForEach(MyStuffViewModel.Segment.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                content
            }
            .navigationTitle("My Stuff")
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.orders.isEmpty && vm.rsvps.isEmpty {
            ProgressView().padding(.top, 30)
        } else if let msg = vm.errorMessage {
            ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(msg))
        } else {
            switch vm.segment {
            case .orders:
                if vm.orders.isEmpty {
                    ContentUnavailableView("No orders yet", systemImage: "bag")
                } else {
                    List(vm.orders) { order in
                        NavigationLink {
                            OrderDetailView(order: order)
                        } label: {
                            EventRow(
                                title: order.event.title,
                                subtitle: order.event.startAt.formatted(date: .abbreviated, time: .shortened),
                                city: order.event.city,
                                coverUrl: order.event.coverUrl,
                                trailing: "\(order.status.uppercased()) • \(formatMoney(cents: order.totalCents, currency: order.currency))"
                            )
                        }
                    }
                }

            case .rsvps:
                if vm.rsvps.isEmpty {
                    ContentUnavailableView("No RSVPs yet", systemImage: "checkmark.circle")
                } else {
                    List(vm.rsvps) { rsvp in
                        NavigationLink {
                            RSVPDetailView(rsvp: rsvp)
                        } label: {
                            EventRow(
                                title: rsvp.event.title,
                                subtitle: rsvp.event.startAt.formatted(date: .abbreviated, time: .shortened),
                                city: rsvp.event.city,
                                coverUrl: rsvp.event.coverUrl,
                                trailing: rsvp.status.uppercased()
                            )
                        }
                    }
                }
            }
        }
    }

    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

private struct EventRow: View {
    let title: String
    let subtitle: String
    let city: String?
    let coverUrl: String?
    let trailing: String

    var body: some View {
        HStack(spacing: 12) {
            coverThumb(urlString: coverUrl)

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

    @ViewBuilder
    private func coverThumb(urlString: String?) -> some View {
        let size: CGFloat = 56
        if let s = urlString, let url = URL(string: s) {
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

// MARK: - Order Detail

struct OrderDetailView: View {
    let order: OrderWithEvent
    @State private var items: [OrderItemWithTicket] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = EventsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Divider()

                Text("Tickets")
                    .font(.headline)

                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if items.isEmpty {
                    Text("No tickets found for this order.").foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            ticketRow(item)
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(formatMoney(cents: order.totalCents, currency: order.currency))
                        .font(.headline)
                }

                Text("Status: \(order.status.uppercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    EventDetailLoaderView(eventId: order.eventId)
                } label: {
                    Text("View event")
                }
                .buttonStyle(.borderedProminent)

                Spacer(minLength: 12)
            }
            .padding()
        }
        .navigationTitle("Order")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let s = order.event.coverUrl, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 16).frame(height: 200)
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(16)
                    case .failure:
                        RoundedRectangle(cornerRadius: 16).frame(height: 200)
                    @unknown default:
                        RoundedRectangle(cornerRadius: 16).frame(height: 200)
                    }
                }
            }

            Text(order.event.title)
                .font(.title2).bold()

            Text(order.event.startAt.formatted(date: .long, time: .shortened))
                .foregroundStyle(.secondary)
        }
    }

    private func ticketRow(_ item: OrderItemWithTicket) -> some View {
        let name = item.ticketType?.name ?? "Ticket"
        let desc = item.ticketType?.description ?? ""

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Text("x\(item.quantity)")
                    .foregroundStyle(.secondary)
            }

            if !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            let lineTotal = item.quantity * item.unitPriceCents
            Text("\(formatMoney(cents: item.unitPriceCents, currency: item.currency)) each • \(formatMoney(cents: lineTotal, currency: item.currency))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await service.fetchOrderItemsWithTicketTypes(orderId: order.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatMoney(cents: Int, currency: String) -> String {
        let amount = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

// MARK: - RSVP Detail (simple)

struct RSVPDetailView: View {
    let rsvp: RSVPWithEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let s = rsvp.event.coverUrl, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 16).frame(height: 220)
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(height: 220)
                            .clipped()
                            .cornerRadius(16)
                    case .failure:
                        RoundedRectangle(cornerRadius: 16).frame(height: 220)
                    @unknown default:
                        RoundedRectangle(cornerRadius: 16).frame(height: 220)
                    }
                }
            }

            Text(rsvp.event.title).font(.title2).bold()
            Text(rsvp.event.startAt.formatted(date: .long, time: .shortened))
                .foregroundStyle(.secondary)
            Text("Status: \(rsvp.status.uppercased())")
                .foregroundStyle(.secondary)

            NavigationLink {
                EventDetailLoaderView(eventId: rsvp.eventId)
            } label: {
                Text("View event")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("RSVP")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Load full Event and push your existing EventDetailView(event:)

struct EventDetailLoaderView: View {
    let eventId: UUID
    @State private var event: Event?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = EventsService()

    var body: some View {
        Group {
            if let event {
                EventDetailView(event: event)
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load event", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView()
                    .task { await load() }
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            event = try await service.fetchEvent(eventId: eventId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
