//  CheckoutView.swift
//  Pulse
//
//  Creates a "reserved" order via RPC (no payments yet).
//

import SwiftUI
import Combine

struct CheckoutSelection: Identifiable {
    let id = UUID()
    let ticketType: TicketType
    var quantity: Int
}

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var orderId: UUID?
    @Published var totalCents: Int = 0

    private let service = EventsService()
    private let event: Event
    private let selections: [CheckoutSelection]

    init(event: Event, selections: [CheckoutSelection]) {
        self.event = event
        self.selections = selections
        self.totalCents = selections.reduce(0) { $0 + $1.quantity * $1.ticketType.priceCents }
    }

    func checkout() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let items = selections
            .filter { $0.quantity > 0 }
            .map { CheckoutItem(ticket_type_id: $0.ticketType.id, quantity: $0.quantity) }

        do {
            let id = try await service.createOrder(eventId: event.id, items: items)
            orderId = id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CheckoutView: View {
    let event: Event
    let selections: [CheckoutSelection]
    @StateObject private var vm: CheckoutViewModel

    init(event: Event, selections: [CheckoutSelection]) {
        self.event = event
        self.selections = selections
        _vm = StateObject(wrappedValue: CheckoutViewModel(event: event, selections: selections))
    }

    var body: some View {
        Form {
            Section("Summary") {
                ForEach(selections.filter { $0.quantity > 0 }) { s in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(s.ticketType.name)
                            if !s.ticketType.description.isEmpty {
                                Text(s.ticketType.description).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("x\(s.quantity)")
                    }
                }

                HStack {
                    Text("Total")
                    Spacer()
                    Text(formatCents(vm.totalCents, currency: "CAD"))
                        .bold()
                }
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(.red) }
            }

            if let orderId = vm.orderId {
                Section("Reserved") {
                    Text("Order created (reserved).")
                    Text(orderId.uuidString)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            } else {
                Section {
                    Button(vm.isLoading ? "Creating order..." : "Checkout") {
                        Task { await vm.checkout() }
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
        .navigationTitle("Checkout")
    }

    private func formatCents(_ cents: Int, currency: String) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "%@ %.2f", currency, dollars)
    }
}
