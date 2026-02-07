import SwiftUI
import Combine
import Supabase

@MainActor
final class EditEventViewModel: ObservableObject {
    @Published var title: String
    @Published var description: String
    @Published var startAt: Date
    @Published var endAt: Date?
    @Published var locationName: String
    @Published var city: String
    @Published var isPublished: Bool

    @Published var isSaving = false
    @Published var errorMessage: String?

    private let eventId: UUID
    private let service: EventsServing

    init(event: Event, service: EventsServing = EventsService()) {
        self.eventId = event.id
        self.title = event.title
        self.description = event.description
        self.startAt = event.startAt
        self.endAt = event.endAt
        self.locationName = event.locationName ?? ""
        self.city = event.city ?? ""
        self.isPublished = event.isPublished
        self.service = service
    }

    func save() async throws {
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let update = EventUpdate(
            title: trimmedTitle,
            description: description,
            start_at: startAt,
            end_at: endAt,
            location_name: locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationName,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city,
            is_published: isPublished
        )

        do {
            try await service.updateEvent(eventId: eventId, update: update)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

struct EditEventView: View {
    let event: Event
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: EditEventViewModel

    init(event: Event, onSaved: @escaping () async -> Void) {
        self.event = event
        self.onSaved = onSaved
        _vm = StateObject(wrappedValue: EditEventViewModel(event: event))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cover") {
                    RemoteEventImageView(urlString: event.coverUrl, width: nil, height: 180, cornerRadius: 12)
                }

                Section("Basics") {
                    TextField("Title", text: $vm.title)
                    TextField("Description", text: $vm.description, axis: .vertical)
                        .lineLimit(3...8)
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

                Section {
                    Toggle("Published", isOn: $vm.isPublished)
                }

                if let message = vm.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(vm.isSaving ? "Saving..." : "Save") {
                        Task {
                            do {
                                try await vm.save()
                                await onSaved()
                                dismiss()
                            } catch {
                                // message handled in view model
                            }
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
        }
    }
}
