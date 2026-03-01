import SwiftUI

struct SettingsView: View {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false
    @StateObject private var healthKit = HealthKitManager.shared

    private let privacyPolicyURL = URL(string: "https://chadnewbry.github.io/VaxNear/privacy-policy.html")!
    private let termsOfServiceURL = URL(string: "https://chadnewbry.github.io/VaxNear/terms-of-service.html")!
    private let supportURL = URL(string: "https://chadnewbry.github.io/VaxNear/support.html")!

    var body: some View {
        NavigationStack {
            List {
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
                    Label("iCloud Sync", systemImage: "icloud")
                    Label("Export Records", systemImage: "square.and.arrow.up")

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
        }
    }
}

#Preview {
    SettingsView()
}
