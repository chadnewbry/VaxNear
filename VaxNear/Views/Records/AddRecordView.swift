import SwiftData
import SwiftUI

struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthKit = HealthKitManager.shared
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]

    var assignToProfile: FamilyProfile?

    @State private var vaccineName = ""
    @State private var manufacturer = ""
    @State private var lotNumber = ""
    @State private var dateAdministered = Date.now
    @State private var provider = ""
    @State private var injectionSite = "Left Arm"
    @State private var notes = ""
    @State private var selectedProfileID: UUID?

    private let siteOptions = ["Left Arm", "Right Arm", "Left Thigh", "Right Thigh", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                if !profiles.isEmpty {
                    Section("Profile") {
                        Picker("For", selection: $selectedProfileID) {
                            Text("Unassigned").tag(nil as UUID?)
                            ForEach(profiles) { profile in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: profile.colorTag))
                                        .frame(width: 8, height: 8)
                                    Text(profile.name)
                                }.tag(profile.id as UUID?)
                            }
                        }
                    }
                }

                Section("Vaccine Information") {
                    TextField("Vaccine Name", text: $vaccineName)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Lot Number", text: $lotNumber)
                }

                Section("Administration") {
                    DatePicker("Date", selection: $dateAdministered, displayedComponents: .date)
                    TextField("Provider / Clinic", text: $provider)
                    Picker("Injection Site", selection: $injectionSite) {
                        ForEach(siteOptions, id: \.self) { Text($0) }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecord() }
                        .disabled(vaccineName.isEmpty)
                }
            }
            .onAppear {
                selectedProfileID = assignToProfile?.id
            }
        }
    }

    private func saveRecord() {
        let profile = profiles.first { $0.id == selectedProfileID }
        let record = VaccinationRecord(
            vaccineName: vaccineName,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            lotNumber: lotNumber.isEmpty ? nil : lotNumber,
            dateAdministered: dateAdministered,
            administeringProvider: provider.isEmpty ? nil : provider,
            injectionSite: injectionSite,
            notes: notes.isEmpty ? nil : notes
        )
        record.profile = profile
        modelContext.insert(record)

        Task {
            await healthKit.syncIfAuthorized(record: record)
        }

        dismiss()
    }
}

#Preview {
    AddRecordView()
}
