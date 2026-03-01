import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]
    @Query(sort: \VaccinationRecord.dateAdministered, order: .reverse)
    private var allRecords: [VaccinationRecord]

    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var wallet = WalletPassManager.shared
    @State private var showingAddRecord = false
    @State private var selectedProfileID: UUID?
    @State private var showingFamilyManagement = false

    private var filteredRecords: [VaccinationRecord] {
        guard let id = selectedProfileID else { return allRecords }
        return allRecords.filter { $0.profile?.id == id }
    }

    private var selectedProfile: FamilyProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredRecords.isEmpty {
                    ContentUnavailableView {
                        Label("No Records", systemImage: "list.clipboard")
                    } description: {
                        Text("Add vaccination records manually or import from HealthKit.")
                    } actions: {
                        Button("Add Record") { showingAddRecord = true }
                            .buttonStyle(.borderedProminent)

                        if healthKit.isAvailable && healthKit.isAuthorized {
                            Button("Import from Health") {
                                Task { await importFromHealthKit() }
                            }
                        }
                    }
                } else {
                    List {
                        ForEach(filteredRecords) { record in
                            RecordRow(record: record)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("Records")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedProfileID = nil
                        } label: {
                            HStack {
                                Text("All Profiles")
                                if selectedProfileID == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        ForEach(profiles) { profile in
                            Button {
                                selectedProfileID = profile.id
                            } label: {
                                HStack {
                                    Text(profile.name)
                                    if selectedProfileID == profile.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            showingFamilyManagement = true
                        } label: {
                            Label("Manage Family", systemImage: "person.3")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if let profile = selectedProfile {
                                Circle()
                                    .fill(Color(hex: profile.colorTag))
                                    .frame(width: 8, height: 8)
                                Text(profile.name)
                                    .font(.subheadline)
                            } else {
                                Image(systemName: "person.2")
                                Text("All")
                                    .font(.subheadline)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddRecord = true } label: {
                        Image(systemName: "plus")
                    }
                }

                if healthKit.isAvailable && healthKit.isAuthorized {
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            Task { await importFromHealthKit() }
                        } label: {
                            Label("Import from Health", systemImage: "heart.text.square")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddRecord) {
                AddRecordView(assignToProfile: selectedProfile)
            }
            .sheet(isPresented: $showingFamilyManagement) {
                NavigationStack {
                    FamilyProfilesView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingFamilyManagement = false }
                            }
                        }
                }
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let records = filteredRecords
        for index in offsets {
            modelContext.delete(records[index])
        }
    }

    private func importFromHealthKit() async {
        let hkRecords = await healthKit.readImmunizationRecords()
        let existingNames = Set(allRecords.map { "\($0.vaccineName)-\($0.dateAdministered)" })

        for hkRecord in hkRecords {
            let key = "\(hkRecord.vaccineName)-\(hkRecord.dateAdministered)"
            if !existingNames.contains(key) {
                let record = VaccinationRecord(
                    vaccineName: hkRecord.vaccineName,
                    dateAdministered: hkRecord.dateAdministered
                )
                modelContext.insert(record)
            }
        }
    }
}

// MARK: - Record Row

struct RecordRow: View {
    let record: VaccinationRecord
    @StateObject private var wallet = WalletPassManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let profile = record.profile {
                    Circle()
                        .fill(Color(hex: profile.colorTag))
                        .frame(width: 8, height: 8)
                }
                Text(record.vaccineName)
                    .font(.headline)
                Spacer()
                Text(record.dateAdministered, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let manufacturer = record.manufacturer, !manufacturer.isEmpty {
                Text(manufacturer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let provider = record.administeringProvider, !provider.isEmpty {
                Text(provider)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if wallet.isWalletAvailable {
                Button {
                    addToWallet()
                } label: {
                    Label("Add to Wallet", systemImage: "wallet.pass")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func addToWallet() {
        do {
            let bundleURL = try wallet.generatePassBundle(for: record)
            print("Pass bundle generated at: \(bundleURL.path)")
        } catch {
            wallet.lastError = error.localizedDescription
        }
    }
}

#Preview {
    RecordsView()
}
