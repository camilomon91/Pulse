//
//  CompleteProfileView.swift
//  Pulse
//
//  Created by Camilo Montero on 2026-02-05.
//

import SwiftUI

struct CompleteProfileView: View {

    @StateObject private var vm = CompleteProfileViewModel()
    @State private var errorMessage: String? = nil
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                Text("Complete Your Profile")
                    .font(.largeTitle)
                    .bold()

                TextField("Full Name", text: $vm.fullName)
                    .textFieldStyle(.roundedBorder)

                DatePicker(
                    "Birthdate",
                    selection: $vm.birthdate,
                    displayedComponents: .date
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("How will you use Pulse?")
                        .font(.headline)

                    Picker("Role", selection: $vm.role) {
                        Label("Browse events & buy tickets", systemImage: "ticket")
                            .tag(UserRole.attendee)

                        Label("Create events & sell tickets", systemImage: "calendar.badge.plus")
                            .tag(UserRole.organizer)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading) {
                    Text("Select Interests")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                        ForEach(vm.allInterests, id: \.self) { interest in
                            Button {
                                toggle(interest)
                            } label: {
                                Text(interest)
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        vm.selectedInterests.contains(interest)
                                        ? Color.blue
                                        : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        vm.selectedInterests.contains(interest)
                                        ? .white
                                        : .primary
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Button {
                    Task {
                        do {
                            try await vm.saveProfile()
                            errorMessage = nil
                            onComplete()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    vm.isLoading ||
                    vm.fullName.isEmpty ||
                    vm.selectedInterests.isEmpty
                )
            }
            .padding()
        }
        .alert("Couldn't save profile", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }

    private func toggle(_ interest: String) {
        if vm.selectedInterests.contains(interest) {
            vm.selectedInterests.remove(interest)
        } else {
            vm.selectedInterests.insert(interest)
        }
    }
}

#Preview {
    CompleteProfileView {
        print("Profile completed (preview)")
    }
}



