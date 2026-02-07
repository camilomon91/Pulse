import SwiftUI
import Combine
import Foundation
import Supabase
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - ViewModel

@MainActor
final class MyStuffViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case orders = "Orders"
        case tickets = "Tickets"
        case rsvps = "RSVPs"
        var id: String { rawValue }
    }

    @Published var segment: Segment = .orders
    @Published var orders: [OrderWithEvent] = []
    @Published var tickets: [TicketWithDetails] = []
    @Published var rsvps: [RSVPWithEvent] = []
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
            async let o = service.fetchMyOrdersWithEvent(limit: 50)
            async let t = service.fetchMyTickets(limit: 100)
            async let r = service.fetchMyRSVPsWithEvent(limit: 50)
            orders = try await o
            tickets = try await t
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
        if vm.isLoading && vm.orders.isEmpty && vm.rsvps.isEmpty && vm.tickets.isEmpty {
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
                                trailing: "\(order.status.uppercased()) • \(CurrencyFormatter.string(cents: order.totalCents, currency: order.currency))"
                            )
                        }
                    }
                }

            case .tickets:
                if vm.tickets.isEmpty {
                    ContentUnavailableView("No tickets yet", systemImage: "ticket")
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your e-tickets")
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(vm.tickets) { ticket in
                                        NavigationLink {
                                            TicketDetailView(ticket: ticket)
                                        } label: {
                                            TicketCarouselCard(ticket: ticket)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 14)
                            }
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
}

private struct EventRow: View {
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

private struct TicketCarouselCard: View {
    let ticket: TicketWithDetails

    var body: some View {
        ZStack {
            ticketBackground

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticket.ticketType?.name ?? "General Admission")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(ticket.event?.title ?? "Event Ticket")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(ticket.isActive ? "ACTIVE" : "DISABLED")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }

                HStack(alignment: .bottom) {
                    EticketQRCodeView(payload: ticket.payloadForQr, qrSize: 112, includeBackground: false)

                    Spacer()

                    Text(ticket.status.uppercased())
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(20)
        }
        .frame(width: 320, height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    @ViewBuilder
    private var ticketBackground: some View {
        if let coverUrl = ticket.event?.coverUrl,
           let url = URL(string: coverUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderBackground
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .overlay(.black.opacity(0.28))
                        .blur(radius: 8)
                        .overlay(.ultraThinMaterial)
                case .failure:
                    placeholderBackground
                @unknown default:
                    placeholderBackground
                }
            }
        } else {
            placeholderBackground
        }
    }

    private var placeholderBackground: some View {
        LinearGradient(
            colors: [.indigo.opacity(0.85), .purple.opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.ultraThinMaterial)
    }
}

struct TicketDetailView: View {
    let ticket: TicketWithDetails

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let event = ticket.event {
                    RemoteEventImageView(urlString: event.coverUrl, width: nil, height: 200, cornerRadius: 16)
                    Text(event.title)
                        .font(.title2)
                        .bold()
                    Text(event.startAt.formatted(date: .long, time: .shortened))
                        .foregroundStyle(.secondary)
                }

                if let ticketTypeName = ticket.ticketType?.name {
                    Text(ticketTypeName)
                        .font(.headline)
                }

                EticketQRCodeView(payload: ticket.payloadForQr)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                Text("Ticket ID: \(ticket.id.uuidString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let scanCode = ticket.scanCode, !scanCode.isEmpty {
                    Text("Scan code: \(scanCode)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Text("Status: \(ticket.status.uppercased())")
                    .foregroundStyle(.secondary)

                Text("State: \(ticket.isActive ? "Enabled" : "Disabled")")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("E-Ticket")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EticketQRCodeView: View {
    let payload: String
    var qrSize: CGFloat = 220
    var includeBackground: Bool = true
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        Group {
            if let image = makeImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrSize, height: qrSize)
                    .padding(includeBackground ? 12 : 0)
                    .background(includeBackground ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
                    .clipShape(RoundedRectangle(cornerRadius: includeBackground ? 14 : 8))
            } else {
                ContentUnavailableView("Could not generate QR", systemImage: "qrcode")
            }
        }
    }

    private func makeImage() -> UIImage? {
        let data = Data(payload.utf8)
        filter.message = data
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

private extension TicketWithDetails {
    var payloadForQr: String {
        if let scanCode, !scanCode.isEmpty {
            return scanCode
        }

        return "PULSE|ticket=\(id.uuidString)|event=\(eventId.uuidString)|owner=\(ownerUserId.uuidString)"
    }
}

// MARK: - Order Detail

struct OrderDetailView: View {
    let order: OrderWithEvent
    @State private var items: [OrderItemWithTicket] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service: EventsServing

    init(order: OrderWithEvent, service: EventsServing = EventsService()) {
        self.order = order
        self.service = service
    }

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
                    Text(CurrencyFormatter.string(cents: order.totalCents, currency: order.currency))
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteEventImageView(urlString: order.event.coverUrl, width: nil, height: 200, cornerRadius: 16)

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
            Text("\(CurrencyFormatter.string(cents: item.unitPriceCents, currency: item.currency)) each • \(CurrencyFormatter.string(cents: lineTotal, currency: item.currency))")
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
}

// MARK: - RSVP Detail (simple)

struct RSVPDetailView: View {
    let rsvp: RSVPWithEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteEventImageView(urlString: rsvp.event.coverUrl, width: nil, height: 220, cornerRadius: 16)

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

    private let service: EventsServing

    init(eventId: UUID, service: EventsServing = EventsService()) {
        self.eventId = eventId
        self.service = service
    }

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
