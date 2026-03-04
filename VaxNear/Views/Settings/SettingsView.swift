import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var profiles: [FamilyProfile]
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.modelContext) private var modelContext
    @State private var showingPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreSuccess = false
    @State private var showingExportSheet = false
    @State private var exportedFileURLs: [URL] = []

    private let privacyPolicyURL = URL(string: "https://chadnewbry.github.io/VaxNear/privacy-policy.html")!
    private let termsOfServiceURL = URL(string: "https://chadnewbry.github.io/VaxNear/terms-of-service.html")!
    private let supportURL = URL(string: "https://chadnewbry.github.io/VaxNear/support.html")!

    private var appSettings: AppSettings {
        AppSettings.shared(in: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Purchase Section
                Section {
                    if appSettings.hasPurchasedFullVersion {
                        Label("Full Version Unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to Full Version", systemImage: "star.fill")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                Text("$4.99")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            Task {
                                restoreSuccess = await storeManager.restorePurchases()
                                if restoreSuccess {
                                    storeManager.syncSettingsIfNeeded(context: modelContext)
                                } else {
                                    showRestoreAlert = true
                                }
                            }
                        } label: {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                        .disabled(storeManager.isLoading)
                    }
                }

                Section("Family") {
                    NavigationLink {
                        FamilyProfilesView()
                    } label: {
                        Label("Manage Family", systemImage: "person.3")
                    }
                }

                Section("Security") {
                    Toggle("Require Face ID", systemImage: "faceid", isOn: $isBiometricLockEnabled)
                }

                Section("Data") {
                    iCloudSyncRow
                    Button { exportAllRecords() } label: {
                        Label("Export Records", systemImage: "square.and.arrow.up")
                    }

                    if healthKit.isAvailable {
                        HStack {
                            Label("HealthKit Sync", systemImage: "heart.text.square")
                            Spacer()
                            if healthKit.isAuthorized {
                                Text("On")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Enable") {
                                    Task { await healthKit.requestAuthorization() }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    } else {
                        HStack {
                            Label("HealthKit", systemImage: "heart.text.square")
                            Spacer()
                            Text("Unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !healthKit.isAuthorized && healthKit.isAvailable {
                    Section {
                        Label(
                            "HealthKit sync is off. Enable it to automatically save vaccination records to Apple Health.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: termsOfServiceURL) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    Link(destination: supportURL) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView {
                    storeManager.syncSettingsIfNeeded(context: modelContext)
                }
            }
            .alert("No Purchase Found", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We couldn't find a previous purchase for this Apple ID.")
            }
            .onChange(of: storeManager.isPurchased) { _, purchased in
                if purchased {
                    storeManager.syncSettingsIfNeeded(context: modelContext)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if !exportedFileURLs.isEmpty {
                    ShareSheet(items: exportedFileURLs)
                }
            }
        }
    }


    private func exportAllRecords() {
        let service = DataExportService(context: modelContext)
        var urls: [URL] = []
        let profilesToExport = profiles.isEmpty ? [] : profiles
        for profile in profilesToExport {
            let pdfData = service.exportAsPDF(profile: profile)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(profile.name)_Vaccination_Records.pdf")
            try? pdfData.write(to: tempURL)
            urls.append(tempURL)
        }
        guard !urls.isEmpty else { return }
        exportedFileURLs = urls
        showingExportSheet = true
    }

    @ViewBuilder
    private var iCloudSyncRow: some View {
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
        if !syncManager.isCloudAvailable {
            Text("Sign in to iCloud in Settings to sync across devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let error = syncManager.syncError {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SyncManager())
}
