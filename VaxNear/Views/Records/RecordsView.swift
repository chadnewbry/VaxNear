import SwiftData
import SwiftUI

struct RecordsView: View {
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]
    @Query(sort: \VaccinationRecord.dateAdministered, order: .reverse)
    private var allRecords: [VaccinationRecord]

    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var showingAddRecord = false
    @StateObject private var navigationState = NavigationState.shared
    @State private var selectedProfileID: UUID?
    @State private var showingFamilyManagement = false
    @State private var showingExportSheet = false
    @State private var pendingProfileFilter: UUID?
    @State private var showingPaywall = false
    @State private var exportedPDFURL: URL?

    private var appSettings: AppSettings {
        AppSettings.shared(in: modelContext)
    }

    private var filteredRecords: [VaccinationRecord] {
        guard let id = selectedProfileID else { return allRecords }
        return allRecords.filter { $0.profile?.id == id }
    }

    private var selectedProfile: FamilyProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    private var recordsByYear: [(year: Int, records: [VaccinationRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record in
            calendar.component(.year, from: record.dateAdministered)
        }
        return grouped.sorted { $0.key > $1.key }.map { (year: $0.key, records: $0.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                freeUsesHeader
                profileSwitcher

                if filteredRecords.isEmpty {
                    emptyState
                } else {
                    timelineList
                }
            }
            .navigationTitle("Records")
            .onAppear {
                if let filter = navigationState.profileFilter {
                    selectedProfileID = filter
                    navigationState.profileFilter = nil
                }
            }
            .onChange(of: navigationState.profileFilter) { _, newValue in
                if let filter = newValue {
                    selectedProfileID = filter
                    navigationState.profileFilter = nil
                }
            }
            .onAppear { ShortcutDonation.donateRecordsView() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { handleAddRecord() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add vaccination record")
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button { exportPDF() } label: {
                        Label("Export Records", systemImage: "square.and.arrow.up")
                    }
                    .disabled(filteredRecords.isEmpty)
                    .accessibilityHint("Export records as PDF")
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
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportedPDFURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView {
                    storeManager.syncSettingsIfNeeded(context: modelContext)
                }
            }
            .onChange(of: storeManager.isPurchased) { _, purchased in
                if purchased {
                    storeManager.syncSettingsIfNeeded(context: modelContext)
                }
            }
        }
    }

    // MARK: - Free Uses Header

    @ViewBuilder
    private var freeUsesHeader: some View {
        let settings = appSettings
        HStack {
            if settings.hasPurchasedFullVersion {
                Label("Full Version", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("\(settings.freeUsesRemaining) of 5 free records remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Upgrade") {
                    showingPaywall = true
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .accessibilityHint("View upgrade options")
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Profile Switcher

    private var profileSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ProfilePill(name: "All", colorHex: nil, isSelected: selectedProfileID == nil) {
                    withAnimation { selectedProfileID = nil }
                }

                ForEach(profiles) { profile in
                    ProfilePill(name: profile.name, colorHex: profile.colorTag, isSelected: selectedProfileID == profile.id) {
                        withAnimation { selectedProfileID = profile.id }
                    }
                }

                Button { showingFamilyManagement = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: profiles.isEmpty ? "plus" : "person.2.badge.gearshape")
                            .font(.caption.bold())
                        if !profiles.isEmpty {
                            Text("Manage")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5))
                }
                .accessibilityLabel(profiles.isEmpty ? "Add family profile" : "Manage family profiles")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Records", systemImage: "list.clipboard")
        } description: {
            Text("Add your first vaccination record")
        } actions: {
            VStack(spacing: 12) {
                Button { handleAddRecord() } label: {
                    Label("Add Record", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button { handleAddRecord() } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        List {
            ForEach(recordsByYear, id: \.year) { group in
                Section {
                    ForEach(group.records) { record in
                        NavigationLink(destination: RecordDetailView(record: record)) {
                            RecordRow(record: record)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(group.records[index]) }
                    }
                } header: {
                    Text(String(group.year))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func handleAddRecord() {
        let settings = appSettings
        if !settings.hasPurchasedFullVersion && settings.freeUsesRemaining <= 0 {
            showingPaywall = true
            return
        }
        showingAddRecord = true
    }

    private func importFromHealthKit() async {
        let hkRecords = await healthKit.readImmunizationRecords()
        let existingKeys = Set(allRecords.map { "\($0.vaccineName)-\($0.dateAdministered)" })
        for hkRecord in hkRecords {
            let key = "\(hkRecord.vaccineName)-\(hkRecord.dateAdministered)"
            guard !existingKeys.contains(key) else { continue }
            let record = VaccinationRecord(vaccineName: hkRecord.vaccineName, dateAdministered: hkRecord.dateAdministered)
            record.profile = selectedProfile
            modelContext.insert(record)
        }
    }

    private func exportPDF() {
        guard let profile = selectedProfile ?? profiles.first else { return }
        let pdfData = DataExportService(context: modelContext).exportAsPDF(profile: profile)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(profile.name)_Vaccination_Records.pdf")
        try? pdfData.write(to: tempURL)
        exportedPDFURL = tempURL
        showingExportSheet = true
    }
}

// MARK: - Profile Pill

struct ProfilePill: View {
    let name: String
    let colorHex: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let hex = colorHex {
                    Circle().fill(Color(hex: hex)).frame(width: 10, height: 10)
                } else {
                    Image(systemName: "person.2").font(.caption2)
                }
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6)))
            .overlay(Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) profile filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Record Row

struct RecordRow: View {
    let record: VaccinationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let profile = record.profile {
                    Circle().fill(Color(hex: profile.colorTag)).frame(width: 8, height: 8)
                }
                Text(record.vaccineName).font(.headline)
                Spacer()
                Text(record.dateAdministered, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let manufacturer = record.manufacturer, !manufacturer.isEmpty {
                Text(manufacturer).font(.subheadline).foregroundStyle(.secondary)
            }

            if let provider = record.administeringProvider, !provider.isEmpty {
                Label(provider, systemImage: "building.2")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !record.sideEffects.isEmpty {
                Label("\(record.sideEffects.count) side effect\(record.sideEffects.count == 1 ? "" : "s")",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recordAccessibilityLabel)
    }

    private var recordAccessibilityLabel: String {
        var parts = [record.vaccineName]
        parts.append(record.dateAdministered.formatted(date: .long, time: .omitted))
        if let profile = record.profile { parts.append("for \(profile.name)") }
        if let mfr = record.manufacturer, !mfr.isEmpty { parts.append(mfr) }
        if !record.sideEffects.isEmpty {
            parts.append("\(record.sideEffects.count) side effect\(record.sideEffects.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    RecordsView()
}
