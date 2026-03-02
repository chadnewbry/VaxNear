import MessageUI
import StoreKit
import SwiftData
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]

    @State private var settings: AppSettings?
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showMailComposer = false

    private let radiusOptions = [5, 10, 25, 50]
    private let advanceNoticeOptions = [1, 3, 7, 14, 30]
    private let vaccineTypes = ["", "COVID-19", "Flu", "Tdap", "MMR", "Hepatitis A", "Hepatitis B", "HPV", "Pneumococcal", "Shingles"]

    private var currentProfile: FamilyProfile? {
        profiles.first { $0.relationship == .selfUser } ?? profiles.first
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                vaccineFinderSection
                notificationsSection
                privacySecuritySection
                appearanceSection
                purchaseStatusSection
                aboutSupportSection
            }
            .navigationTitle("Settings")
            .onAppear { settings = AppSettings.shared(in: modelContext) }
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all profiles, vaccination records, and settings. This cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    toRecipients: ["chad.newbry@gmail.com"],
                    subject: "VaxNear Support",
                    body: "\n\n---\nApp Version: \(appVersion) (\(buildNumber))\niOS \(UIDevice.current.systemVersion)"
                )
            }
        }
    }

    // MARK: - 1. Profile & Family

    @ViewBuilder
    private var profileSection: some View {
        Section("Profile & Family") {
            if let profile = currentProfile {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: profile.colorTag))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(.headline)
                        Text(profile.relationship.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    NavigationLink(destination: AddEditProfileView(existingProfile: profile)) {
                        EmptyView()
                    }
                    .frame(width: 0)
                    .opacity(0)
                }
            }

            NavigationLink {
                FamilyProfilesView()
            } label: {
                Label("Manage Family Profiles", systemImage: "person.3")
            }
        }
    }

    // MARK: - 2. Vaccine Finder

    @ViewBuilder
    private var vaccineFinderSection: some View {
        Section("Vaccine Finder") {
            if let settings {
                Picker("Search Radius", selection: Binding(
                    get: { settings.searchRadiusMiles },
                    set: { settings.searchRadiusMiles = $0; save() }
                )) {
                    ForEach(radiusOptions, id: \.self) { miles in
                        Text("\(miles) miles").tag(miles)
                    }
                }

                Picker("Default Vaccine Type", selection: Binding(
                    get: { settings.defaultVaccineTypeFilter },
                    set: { settings.defaultVaccineTypeFilter = $0; save() }
                )) {
                    Text("All Types").tag("")
                    ForEach(vaccineTypes.filter { !$0.isEmpty }, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
            }
        }
    }

    // MARK: - 3. Notifications

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            if let settings {
                Toggle("Booster Reminders", isOn: Binding(
                    get: { settings.boosterRemindersEnabled },
                    set: { settings.boosterRemindersEnabled = $0; save() }
                ))

                Toggle("Seasonal Vaccine Alerts", isOn: Binding(
                    get: { settings.seasonalAlertsEnabled },
                    set: { settings.seasonalAlertsEnabled = $0; save() }
                ))

                Toggle("Child Milestone Notifications", isOn: Binding(
                    get: { settings.childMilestoneNotificationsEnabled },
                    set: { settings.childMilestoneNotificationsEnabled = $0; save() }
                ))

                Picker("Advance Notice", selection: Binding(
                    get: { settings.notificationAdvanceDays },
                    set: { settings.notificationAdvanceDays = $0; save() }
                )) {
                    ForEach(advanceNoticeOptions, id: \.self) { days in
                        Text(days == 1 ? "1 day before" : "\(days) days before").tag(days)
                    }
                }

                DatePicker("Quiet Hours Start", selection: Binding(
                    get: { settings.quietHoursStart ?? Calendar.current.date(from: DateComponents(hour: 22)) ?? Date() },
                    set: { settings.quietHoursStart = $0; save() }
                ), displayedComponents: .hourAndMinute)

                DatePicker("Quiet Hours End", selection: Binding(
                    get: { settings.quietHoursEnd ?? Calendar.current.date(from: DateComponents(hour: 8)) ?? Date() },
                    set: { settings.quietHoursEnd = $0; save() }
                ), displayedComponents: .hourAndMinute)
            }
        }
    }

    // MARK: - 4. Privacy & Security

    @ViewBuilder
    private var privacySecuritySection: some View {
        Section("Privacy & Security") {
            if let settings {
                Toggle(isOn: Binding(
                    get: { settings.isBiometricLockEnabled },
                    set: { settings.isBiometricLockEnabled = $0; save() }
                )) {
                    Label("Biometric Lock", systemImage: "faceid")
                }

                HStack {
                    Label {
                        Text("iCloud Sync")
                    } icon: {
                        Image(systemName: syncManager.isCloudAvailable ? "icloud.fill" : "icloud.slash")
                            .foregroundStyle(syncManager.isCloudAvailable ? .blue : .secondary)
                    }
                    Spacer()
                    if syncManager.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else if syncManager.isCloudAvailable {
                        if let lastSynced = syncManager.lastSyncedDate {
                            Text(lastSynced, format: .relative(presentation: .named))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            Text("On")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("Unavailable")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    exportAllData()
                } label: {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - 5. Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            HStack {
                Label("Theme", systemImage: "paintbrush")
                Spacer()
                Text("System")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("App Icon", systemImage: "app")
                Spacer()
                Image(systemName: "syringe")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - 6. Purchase Status

    @ViewBuilder
    private var purchaseStatusSection: some View {
        Section("Purchase Status") {
            if let settings {
                if settings.hasPurchasedFullVersion {
                    Label("✓ Full Version — Thank you!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Label("Free", systemImage: "gift")
                        Spacer()
                        Text("\(settings.freeUsesRemaining) records remaining")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        // Purchase flow placeholder
                    } label: {
                        Label("Upgrade to Full Version", systemImage: "star.fill")
                    }
                }

                Button {
                    // Restore purchases placeholder
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - 7. About & Support

    @ViewBuilder
    private var aboutSupportSection: some View {
        Section("About & Support") {
            Link(destination: URL(string: "https://chadnewbry.github.io/VaxNear/privacy-policy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://chadnewbry.github.io/VaxNear/terms-of-service.html")!) {
                Label("Terms of Use", systemImage: "doc.text")
            }

            Button {
                if MFMailComposeViewController.canSendMail() {
                    showMailComposer = true
                } else if let url = URL(string: "mailto:chad.newbry@gmail.com?subject=VaxNear%20Support") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Customer Support", systemImage: "envelope")
            }

            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundStyle(.secondary)
            }

            Button {
                requestAppReview()
            } label: {
                Label("Rate VaxNear", systemImage: "star.bubble")
            }

            NavigationLink {
                AcknowledgmentsView()
            } label: {
                Label("Acknowledgments", systemImage: "doc.plaintext")
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func save() {
        try? modelContext.save()
    }

    private func exportAllData() {
        let service = DataExportService(context: modelContext)
        var allExports: [ProfileExport] = []
        let formatter = ISO8601DateFormatter()

        for profile in profiles {
            let export = ProfileExport(
                name: profile.name,
                relationship: profile.relationship.rawValue,
                dateOfBirth: formatter.string(from: profile.dateOfBirth),
                records: profile.vaccinationRecords
                    .sorted { $0.dateAdministered < $1.dateAdministered }
                    .map { r in
                        ProfileExport.RecordExport(
                            vaccineName: r.vaccineName,
                            manufacturer: r.manufacturer,
                            lotNumber: r.lotNumber,
                            dateAdministered: formatter.string(from: r.dateAdministered),
                            administeringProvider: r.administeringProvider,
                            injectionSite: r.injectionSite,
                            notes: r.notes
                        )
                    }
            )
            allExports.append(export)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(allExports) else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("VaxNear-Export.json")
        try? data.write(to: tempURL)
        exportURL = tempURL
        showExportSheet = true
    }

    private func deleteAllData() {
        let service = DataExportService(context: modelContext)
        try? service.deleteAllData()
    }

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}


// MARK: - MailComposerView

struct MailComposerView: UIViewControllerRepresentable {
    let toRecipients: [String]
    let subject: String
    let body: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(toRecipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - AcknowledgmentsView

struct AcknowledgmentsView: View {
    var body: some View {
        List {
            Section {
                Text("VaxNear is built with care using Apple's SwiftUI, SwiftData, MapKit, and CloudKit frameworks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Frameworks & Technologies") {
                acknowledgmentRow("SwiftUI", "Apple's declarative UI framework")
                acknowledgmentRow("SwiftData", "Apple's persistence framework")
                acknowledgmentRow("MapKit", "Apple's mapping framework")
                acknowledgmentRow("CloudKit", "Apple's cloud sync framework")
                acknowledgmentRow("HealthKit", "Apple's health data framework")
                acknowledgmentRow("StoreKit", "Apple's in-app purchase framework")
            }

            Section("Data Sources") {
                acknowledgmentRow("CDC", "Immunization schedules and vaccine information")
            }
        }
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func acknowledgmentRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SyncManager())
        .modelContainer(for: [FamilyProfile.self, AppSettings.self], inMemory: true)
}
