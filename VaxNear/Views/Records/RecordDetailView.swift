import SwiftData
import SwiftUI

struct RecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var wallet = WalletPassManager.shared
    @Bindable var record: VaccinationRecord

    @State private var showingEditSheet = false
    @State private var showingSideEffectSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main Info Card
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.vaccineName)
                                    .font(.title2.bold())
                                if let profile = record.profile {
                                    HStack(spacing: 6) {
                                        Circle().fill(Color(hex: profile.colorTag)).frame(width: 8, height: 8)
                                        Text(profile.name).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "syringe")
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                        }

                        Divider()

                        detailRow("Date", value: record.dateAdministered.formatted(date: .long, time: .omitted))
                        detailRow("Manufacturer", value: record.manufacturer)
                        detailRow("Lot Number", value: record.lotNumber)
                        detailRow("Provider", value: record.administeringProvider)
                        detailRow("Injection Site", value: record.injectionSite)

                        if let notes = record.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes").font(.caption).foregroundStyle(.secondary)
                                Text(notes).font(.body)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Side Effects Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Side Effects", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Spacer()
                            Button { showingSideEffectSheet = true } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                        }

                        if record.sideEffects.isEmpty {
                            Text("No side effects reported")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(record.sideEffects.sorted(by: { $0.onsetDate < $1.onsetDate })) { effect in
                                SideEffectRow(effect: effect)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // QR Code
                if record.smartHealthCardData != nil {
                    GroupBox {
                        VStack(spacing: 8) {
                            Label("SMART Health Card", systemImage: "qrcode")
                                .font(.headline)
                            Text("QR code data available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }

                // Action Buttons
                VStack(spacing: 12) {
                    if wallet.isWalletAvailable {
                        Button {
                            addToWallet()
                        } label: {
                            Label("Add to Apple Wallet", systemImage: "wallet.pass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        prepareShare()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    HStack(spacing: 12) {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Record Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            AddRecordView(assignToProfile: record.profile, existingRecord: record)
        }
        .sheet(isPresented: $showingSideEffectSheet) {
            AddSideEffectView(record: record)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .confirmationDialog("Delete Record?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(record)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this vaccination record and its side effects.")
        }
    }

    // MARK: - Detail Row

    @ViewBuilder
    private func detailRow(_ label: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)
                Text(value)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Actions

    private func addToWallet() {
        do {
            let _ = try wallet.generatePassBundle(for: record)
        } catch {
            wallet.lastError = error.localizedDescription
        }
    }

    private func prepareShare() {
        var text = "Vaccination Record\n\n"
        text += "Vaccine: \(record.vaccineName)\n"
        text += "Date: \(record.dateAdministered.formatted(date: .long, time: .omitted))\n"
        if let m = record.manufacturer { text += "Manufacturer: \(m)\n" }
        if let l = record.lotNumber { text += "Lot #: \(l)\n" }
        if let p = record.administeringProvider { text += "Provider: \(p)\n" }
        if let s = record.injectionSite { text += "Site: \(s)\n" }
        if let n = record.notes { text += "Notes: \(n)\n" }
        text += "\nShared via VaxNear"

        shareItems = [text]
        showingShareSheet = true
    }
}

// MARK: - Side Effect Row

struct SideEffectRow: View {
    let effect: SideEffectLog

    var severityColor: Color {
        switch effect.severity {
        case .mild: return .green
        case .moderate: return .orange
        case .severe: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(effect.symptom)
                    .font(.subheadline.bold())
                Spacer()
                Text(effect.severity.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 12) {
                Label(effect.onsetDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let days = effect.durationDays {
                    Label("\(days) day\(days == 1 ? "" : "s")", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let notes = effect.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(record: VaccinationRecord(
            vaccineName: "COVID-19 Pfizer",
            manufacturer: "Pfizer-BioNTech",
            lotNumber: "EK9788",
            dateAdministered: Date(),
            administeringProvider: "CVS Pharmacy",
            injectionSite: "Left Arm"
        ))
    }
}
