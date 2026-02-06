//  EventDetailView.swift
//  Pulse
//

import SwiftUI
import Combine


@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var ticketTypes: [TicketType] = []
    @Published var quantities: [UUID: Int] = [:]   // ticket_type_id -> qty

    // RSVP (for free events)
    @Published var myRSVP: EventRSVP?

    private let service: EventsServiceProtocol
    private let event: Event

    init(event: Event, service: EventsServiceProtocol = EventsService()) {
        self.event = event
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if event.isFree {
                myRSVP = try await service.getMyRSVP(eventId: event.id)
            } else {
                ticketTypes = try await service.fetchTicketTypes(eventId: event.id)

                // init quantities once
                if quantities.isEmpty {
                    for t in ticketTypes { quantities[t.id] = 0 }
                }

                // clamp existing selections to capacity (important after reload)
                for t in ticketTypes {
                    let current = quantities[t.id] ?? 0
                    quantities[t.id] = min(max(0, current), max(0, t.available))
                }
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setQuantity(ticketTypeId: UUID, qty: Int) {
        let cap = ticketTypes.first(where: { $0.id == ticketTypeId })?.available ?? 0
        quantities[ticketTypeId] = min(max(0, qty), max(0, cap))
    }
    
    var totalSelectedTickets: Int {
        quantities.values.reduce(0, +)
    }



    func buildSelections() -> [CheckoutSelection] {
        ticketTypes.map { t in
            CheckoutSelection(
                ticketType: t,
                quantity: quantities[t.id] ?? 0
            )
        }
    }

    var hasAtLeastOneTicket: Bool {
        quantities.values.contains(where: { $0 > 0 })
    }

    // MARK: RSVP

    func rsvpGoing() async {
        errorMessage = nil
        do {
            try await service.upsertRSVP(eventId: event.id, status: "going")
            myRSVP = try await service.getMyRSVP(eventId: event.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRSVP() async {
        errorMessage = nil
        do {
            try await service.cancelRSVP(eventId: event.id)
            myRSVP = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct EventDetailView: View {
    let event: Event
    @StateObject private var vm: EventDetailViewModel

    @State private var goCheckout = false

    init(event: Event) {
        self.event = event
        _vm = StateObject(wrappedValue: EventDetailViewModel(event: event, service: EventsService()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // Cover header (optional)
                coverHeader

                Text(event.title)
                    .font(.title2).bold()

                Text(event.startAt.formatted(date: .long, time: .shortened))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let location = event.locationName ?? event.locationAddress ?? event.city,
                   !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(event.description.isEmpty ? "No description provided." : event.description)
                    .font(.body)

                if let err = vm.errorMessage {
                    Text(err).foregroundStyle(.red)
                }

                Divider()

                if vm.isLoading {
                    ProgressView().padding(.top, 8)

                } else if event.isFree {
                    freeEventSection

                } else {
                    paidEventSection
                }
            }
            .padding()
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .onChange(of: goCheckout) { oldValue, newValue in
            // newValue is the current value
            if oldValue == true && newValue == false {
                Task { await vm.load() }
            }
        }

        .navigationDestination(isPresented: $goCheckout) {
            CheckoutView(
                event: event,
                selections: vm.buildSelections().filter { $0.quantity > 0 }
            )
        }

    }

    // MARK: - Sections

    private var freeEventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RSVP")
                .font(.headline)

            if vm.myRSVP == nil {
                Button("RSVP (Going)") {
                    Task { await vm.rsvpGoing() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Cancel RSVP") {
                    Task { await vm.cancelRSVP() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var paidEventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tickets")
                    .font(.headline)

                Spacer()

                if vm.totalSelectedTickets > 0 {
                    Text("Selected: \(vm.totalSelectedTickets)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if vm.ticketTypes.isEmpty {
                Text("No tickets available.")
                    .foregroundStyle(.secondary)

            } else {
                ForEach(vm.ticketTypes) { t in
                    let cap = max(0, t.available)
                    let selected = vm.quantities[t.id] ?? 0
                    let isSoldOut = cap == 0

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(t.name).font(.headline)

                                    if isSoldOut {
                                        Text("SOLD OUT")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.thinMaterial)
                                            .clipShape(Capsule())
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if !t.description.isEmpty {
                                    Text(t.description)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 10) {
                                    Text(CurrencyFormatter.string(cents: t.priceCents, currency: t.currency))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("Available: \(cap)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Stepper(
                                value: Binding(
                                    get: { selected },
                                    set: { vm.setQuantity(ticketTypeId: t.id, qty: $0) }
                                ),
                                in: 0...cap
                            ) {
                                Text("\(selected)")
                                    .frame(minWidth: 28, alignment: .trailing)
                            }
                            .labelsHidden()
                            .disabled(isSoldOut)
                        }
                    }
                    .padding(.vertical, 6)
                    .opacity(isSoldOut ? 0.55 : 1.0)

                    Divider()
                }

                Button("Continue to Checkout") {
                    goCheckout = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.hasAtLeastOneTicket)
                .padding(.top, 8)
            }
        }
    }


    // MARK: - Helpers


    @ViewBuilder
    private var coverHeader: some View {
        if let urlString = event.coverUrl {
            EventImageView(urlString: urlString, width: nil, height: 220, cornerRadius: 16)
                .padding(.bottom, 6)
        }
    }
}
