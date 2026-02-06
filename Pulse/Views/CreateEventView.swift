//
//  CreateEventView.swift
//  Pulse
//

import SwiftUI
import PhotosUI
import UIKit
import Combine
import Supabase

@MainActor
final class CreateEventViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var startAt = Date()
    @Published var endAt: Date? = nil
    @Published var locationName = ""
    @Published var city = ""

    // Ticketing
    @Published var isFree = true
    @Published var rsvpCapacityText = ""   // optional int text for free events

    // Cover (data only lives in VM)
    @Published var coverImageData: Data? = nil

    @Published var isPublished = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service: EventsServiceProtocol

    init(service: EventsServiceProtocol = EventsService()) {
        self.service = service
    }

    func save(ticketTypes: [TicketTypeDraft]) async {
        errorMessage = nil
        successMessage = nil

        guard let user = supabase.auth.currentUser else {
            errorMessage = "You are not logged in."
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            errorMessage = "Title is required."
            return
        }

        // RSVP capacity (optional) only for free events
        var rsvpCap: Int? = nil
        if isFree {
            let trimmed = rsvpCapacityText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                guard let val = Int(trimmed), val > 0 else {
                    errorMessage = "RSVP capacity must be a positive number."
                    return
                }
                rsvpCap = val
            }
        }

        isLoading = true
        defer { isLoading = false }

        let insert = EventInsert(
            creator_id: user.id,
            title: trimmedTitle,
            description: description,
            start_at: startAt,
            end_at: endAt,
            location_name: locationName.isEmpty ? nil : locationName,
            location_address: nil,
            city: city.isEmpty ? nil : city,
            cover_url: nil, // updated after upload
            category: nil,
            is_free: isFree,
            rsvp_capacity: rsvpCap,
            is_published: isPublished
        )

        do {
            let created = try await service.createEventReturning(insert)

            // If ticketed, create ticket types
            if !isFree {
                // Validate drafts
                for d in ticketTypes {
                    let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.isEmpty {
                        errorMessage = "Each ticket type must have a name."
                        return
                    }
                    let price = Int(d.priceCentsText) ?? 0
                    let cap = Int(d.capacityText) ?? 0
                    if cap <= 0 {
                        errorMessage = "Ticket capacity must be greater than 0."
                        return
                    }
                    if price < 0 {
                        errorMessage = "Ticket price cannot be negative."
                        return
                    }
                }

                let inserts: [TicketTypeInsert] = ticketTypes.map { d in
                    TicketTypeInsert(
                        event_id: created.id,
                        creator_id: user.id,
                        name: d.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: d.description,
                        price_cents: Int(d.priceCentsText) ?? 0,
                        currency: d.currency,
                        capacity: Int(d.capacityText) ?? 0,
                        is_active: true
                    )
                }

                try await service.createTicketTypes(inserts)
            }


            // Upload cover image (optional)
            if let jpeg = coverImageData {
                let coverURL = try await service.uploadEventCover(eventId: created.id, jpegData: jpeg)
                try await service.updateEventCoverURL(eventId: created.id, coverURL: coverURL)
            }

            successMessage = isPublished ? "Event published!" : "Draft saved!"

            // reset
            title = ""
            description = ""
            startAt = Date()
            endAt = nil
            locationName = ""
            city = ""
            isPublished = false
            isFree = true
            rsvpCapacityText = ""
            coverImageData = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Draft ticket type used in UI
// Draft ticket type used in UI (Strings for stable editing in Form)
struct TicketTypeDraft: Identifiable {
    var id = UUID()
    var name: String
    var description: String
    var priceCentsText: String
    var capacityText: String
    var currency: String
}


struct CreateEventView: View {
    @StateObject private var vm = CreateEventViewModel()

    // Cover picker (VIEW state only)
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var coverPreview: Image? = nil

    // Ticket types UI
    @State private var ticketDrafts: [TicketTypeDraft] = [
        TicketTypeDraft(
            name: "General Admission",
            description: "",
            priceCentsText: "2500",
            capacityText: "50",
            currency: "CAD"
        )
    ]


    var body: some View {
        NavigationStack {
            Form {
                Section("Cover") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(coverPreview == nil ? "Choose cover image" : "Change cover image")
                        }
                    }

                    if let preview = coverPreview {
                        preview
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(12)

                        Button(role: .destructive) {
                            selectedPhoto = nil
                            vm.coverImageData = nil
                            coverPreview = nil   // ✅ now this refers to the @State var
                        } label: {
                            Text("Remove cover")
                        }
                    }

                }
                .onChange(of: selectedPhoto) { _, newValue in
                    guard let newValue else { return }
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let compressed = data.jpegCompressed(maxBytes: 900_000) {
                            vm.coverImageData = compressed
                            if let uiImg = UIImage(data: compressed) {
                                coverPreview = Image(uiImage: uiImg)
                            }
                        }
                    }
                }

                Section("Basics") {
                    TextField("Title", text: $vm.title)
                    TextField("Description", text: $vm.description, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("When") {
                    DatePicker("Start", selection: $vm.startAt)
                    Toggle("Add end time", isOn: Binding(
                        get: { vm.endAt != nil },
                        set: { vm.endAt = $0 ? vm.startAt.addingTimeInterval(3600) : nil }
                    ))
                    if let end = vm.endAt {
                        DatePicker("End", selection: Binding(
                            get: { end },
                            set: { vm.endAt = $0 }
                        ))
                    }
                }

                Section("Where") {
                    TextField("Location name", text: $vm.locationName)
                    TextField("City", text: $vm.city)
                }

                Section("Tickets") {
                    Toggle("Free event (RSVP)", isOn: $vm.isFree)

                    if vm.isFree {
                        TextField("RSVP capacity (optional)", text: $vm.rsvpCapacityText)
                            .keyboardType(.numberPad)
                    } else {
                        ticketEditor
                    }
                }

                Section {
                    Toggle("Publish now", isOn: $vm.isPublished)
                }

                if let err = vm.errorMessage {
                    Section { Text(err).foregroundStyle(.red) }
                }

                if let ok = vm.successMessage {
                    Section { Text(ok).foregroundStyle(.green) }
                }

                Section {
                    Button(vm.isLoading ? "Saving..." : "Save") {
                        // ✅ commits text fields that are still being edited
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                        Task {
                            await vm.save(ticketTypes: normalizedTicketDrafts())
                        }
                    }
                    .disabled(vm.isLoading)

                }
            }
            .navigationTitle("Create")
        }
    }
    private func normalizedTicketDrafts() -> [TicketTypeDraft] {
        // Strip non-digits so "2,500" doesn’t break parsing
        ticketDrafts.map { d in
            var copy = d
            copy.priceCentsText = d.priceCentsText.filter(\.isNumber)
            copy.capacityText = d.capacityText.filter(\.isNumber)
            return copy
        }
    }


    @ViewBuilder
    private var ticketEditor: some View {
        ForEach(ticketDrafts.indices, id: \.self) { i in
            Section {
                TextField("Ticket name", text: $ticketDrafts[i].name)
                TextField("Description", text: $ticketDrafts[i].description)

                TextField("Price (cents)", text: $ticketDrafts[i].priceCentsText)
                    .keyboardType(.numberPad)

                TextField("Capacity", text: $ticketDrafts[i].capacityText)
                    .keyboardType(.numberPad)

                Button(role: .destructive) {
                    ticketDrafts.remove(at: i)
                } label: {
                    Text("Remove ticket type")
                }
            } header: {
                Text("Ticket \(i + 1)")
            }
        }

        Button {
            // ✅ append MUST happen on main actor; we're in View so it is.
            ticketDrafts.append(
                TicketTypeDraft(
                    name: "New Ticket",
                    description: "",
                    priceCentsText: "0",
                    capacityText: "10",
                    currency: "CAD"
                )
            )
        } label: {
            Label("Add ticket type", systemImage: "plus")
        }
    }

    
    private func intTextBinding(get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<String> {
        Binding<String>(
            get: { String(get()) },
            set: { newValue in
                // keep only digits
                let digits = newValue.filter { $0.isNumber }
                set(Int(digits) ?? 0)
            }
        )
    }


}

// Image compression helper
private extension Data {
    func jpegCompressed(maxBytes: Int) -> Data? {
        guard let image = UIImage(data: self) else { return nil }

        var quality: CGFloat = 0.85
        var out = image.jpegData(compressionQuality: quality)

        while let data = out, data.count > maxBytes, quality > 0.2 {
            quality -= 0.1
            out = image.jpegData(compressionQuality: quality)
        }
        return out
    }
}


