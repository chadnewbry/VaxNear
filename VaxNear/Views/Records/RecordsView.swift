import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \VaccinationRecord.dateAdministered, order: .reverse)
    private var records: [VaccinationRecord]

    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var wallet = WalletPassManager.shared
    @State private var showingAddRecord = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
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
                        ForEach(records) { record in
                            RecordRow(record: record)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("Records")
            .toolbar {
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
                AddRecordView()
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }

    private func importFromHealthKit() async {
        let hkRecords = await healthKit.readImmunizationRecords()
        let existingNames = Set(records.map { "\($0.vaccineName)-\($0.dateAdministered)" })

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
            // In production, the bundle would be signed server-side
            // and the signed .pkpass data passed to addToWallet(passData:)
            print("Pass bundle generated at: \(bundleURL.path)")
        } catch {
            wallet.lastError = error.localizedDescription
        }
    }
}

#Preview {
    RecordsView()
}
