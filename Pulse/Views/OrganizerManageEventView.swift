import SwiftUI
import AVFoundation
import Combine

@MainActor
final class OrganizerManageEventViewModel: ObservableObject {
    enum Segment: String, CaseIterable, Identifiable {
        case orders = "Orders"
        case tickets = "Tickets"

        var id: String { rawValue }
    }

    @Published var segment: Segment = .orders
    @Published var orders: [OrganizerOrderWithDetails] = []
    @Published var tickets: [TicketWithDetails] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profileNames: [UUID: String] = [:]
    @Published var scannedTicket: TicketWithDetails?
    @Published var scanFeedback: String?
    @Published var isProcessingScan = false

    private let service: EventsServing
    private let eventId: UUID

    init(eventId: UUID, service: EventsServing = EventsService()) {
        self.eventId = eventId
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let organizerOrders = service.fetchOrganizerOrdersWithDetails(eventId: eventId, limit: 100)
            async let organizerTickets = service.fetchOrganizerTickets(eventId: eventId, limit: 400)
            orders = try await organizerOrders
            tickets = try await organizerTickets
            await resolveProfileNames()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveProfileNames() async {
        let ids = Set(orders.map(\.userId) + tickets.map(\.ownerUserId))
        guard !ids.isEmpty else {
            profileNames = [:]
            return
        }

        var result: [UUID: String] = [:]
        for id in ids {
            if let profile = try? await service.fetchProfileSnippet(userId: id),
               let fullName = profile.fullName,
               !fullName.isEmpty {
                result[id] = fullName
            }
        }

        profileNames = result
    }

    func processScannedCode(_ code: String) async {
        guard !isProcessingScan else { return }
        isProcessingScan = true
        defer { isProcessingScan = false }

        do {
            let ticketByCode = try await service.fetchOrganizerTicketByScanCode(eventId: eventId, scanCode: code)
            let ticketByPayload: TicketWithDetails?
            if ticketByCode == nil, let payloadTicketId = parsePayloadTicketId(code) {
                ticketByPayload = try await service.fetchOrganizerTicketById(eventId: eventId, ticketId: payloadTicketId)
            } else {
                ticketByPayload = nil
            }

            guard let ticket = ticketByCode ?? ticketByPayload else {
                scanFeedback = "Ticket not found for this event."
                return
            }

            scannedTicket = ticket
            scanFeedback = nil

            // First scan consumes the ticket only once.
            if ticket.isActive && ticket.scannedAt == nil {
                try await service.markTicketScanned(ticketId: ticket.id, scannedAt: Date())
                await load()
                if let refreshed = try await service.fetchOrganizerTicketById(eventId: eventId, ticketId: ticket.id) {
                    scannedTicket = refreshed
                }
                scanFeedback = "Ticket scanned and disabled."
            } else if ticket.scannedAt != nil {
                scanFeedback = "Ticket already scanned. You can still toggle enable/disable manually."
            }
        } catch {
            scanFeedback = error.localizedDescription
        }
    }


    private func parsePayloadTicketId(_ code: String) -> UUID? {
        guard code.hasPrefix("PULSE|") else { return nil }
        let parts = code.split(separator: "|")
        for part in parts {
            if part.hasPrefix("ticket=") {
                let value = part.replacingOccurrences(of: "ticket=", with: "")
                return UUID(uuidString: value)
            }
        }
        return nil
    }

    func toggleTicket(_ ticket: TicketWithDetails) async {
        do {
            try await service.setTicketActive(ticketId: ticket.id, isActive: !ticket.isActive)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OrganizerManageEventView: View {
    let event: Event
    @StateObject private var vm: OrganizerManageEventViewModel
    @State private var isScannerPresented = false

    init(event: Event) {
        self.event = event
        _vm = StateObject(wrappedValue: OrganizerManageEventViewModel(eventId: event.id))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $vm.segment) {
                    ForEach(OrganizerManageEventViewModel.Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if vm.isLoading && vm.orders.isEmpty && vm.tickets.isEmpty {
                    ProgressView().padding(.top, 30)
                } else if let errorMessage = vm.errorMessage,
                          vm.orders.isEmpty && vm.tickets.isEmpty {
                    ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    content
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isScannerPresented = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $isScannerPresented) {
                OrganizerTicketScannerSheet(vm: vm)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.segment {
        case .orders:
            if vm.orders.isEmpty {
                ContentUnavailableView("No orders yet", systemImage: "cart")
            } else {
                List(vm.orders) { order in
                    NavigationLink {
                        OrganizerOrderDetailView(order: order)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(vm.profileNames[order.userId] ?? order.buyer?.fullName ?? order.userId.uuidString)
                                .font(.headline)
                            Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(order.status.uppercased()) • \(CurrencyFormatter.string(cents: order.totalCents, currency: order.currency))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

        case .tickets:
            if vm.tickets.isEmpty {
                ContentUnavailableView("No tickets yet", systemImage: "ticket")
            } else {
                List(vm.tickets) { ticket in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ticket.ticketType?.name ?? "Ticket")
                            .font(.headline)

                        Text("Owner: \(vm.profileNames[ticket.ownerUserId] ?? ticket.owner?.fullName ?? ticket.ownerUserId.uuidString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Status: \(ticket.status.uppercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Created: \(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button(ticket.isActive ? "Disable ticket" : "Enable ticket") {
                            Task { await vm.toggleTicket(ticket) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ticket.isActive ? .red : .green)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

struct OrganizerOrderDetailView: View {
    let order: OrganizerOrderWithDetails
    @State private var items: [OrderItemWithTicket] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service: EventsServing = EventsService()

    var body: some View {
        List {
            Section("Order") {
                DetailRow(title: "Buyer", value: order.buyer?.fullName ?? order.userId.uuidString)
                DetailRow(title: "Order ID", value: order.id.uuidString)
                DetailRow(title: "Status", value: order.status.uppercased())
                DetailRow(title: "Total", value: CurrencyFormatter.string(cents: order.totalCents, currency: order.currency))
                DetailRow(title: "Created", value: order.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Items") {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if items.isEmpty {
                    Text("No order items")
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.ticketType?.name ?? "Ticket")
                                .font(.headline)
                            Text("Quantity: \(item.quantity)")
                                .foregroundStyle(.secondary)
                            Text("Unit: \(CurrencyFormatter.string(cents: item.unitPriceCents, currency: item.currency))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Order details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
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

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}


struct OrganizerTicketScannerSheet: View {
    @ObservedObject var vm: OrganizerManageEventViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                QRCodeScannerView { code in
                    Task { await vm.processScannedCode(code) }
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if vm.isProcessingScan {
                    ProgressView("Processing scan...")
                }

                if let feedback = vm.scanFeedback {
                    Text(feedback)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let ticket = vm.scannedTicket {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ticket.ticketType?.name ?? "Ticket")
                            .font(.headline)
                        Text("Status: \(ticket.status.uppercased())")
                            .foregroundStyle(.secondary)
                        Text("State: \(ticket.isActive ? "Enabled" : "Disabled")")
                            .foregroundStyle(.secondary)

                        Button(ticket.isActive ? "Disable ticket" : "Enable ticket") {
                            Task {
                                await vm.toggleTicket(ticket)
                                if let code = ticket.scanCode {
                                    await vm.processScannedCode(code)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ticket.isActive ? .red : .green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Scan Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastCode: String?
    private var lastScanTime: Date = .distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCapture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func setupCapture() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else { return }
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        captureSession.startRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let code = object.stringValue else {
            return
        }

        let now = Date()
        if code == lastCode && now.timeIntervalSince(lastScanTime) < 1.5 {
            return
        }

        lastCode = code
        lastScanTime = now
        onCodeScanned?(code)
    }
}
