import SwiftUI

struct SettingsView: View {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false

    private let privacyPolicyURL = URL(string: "https://chadnewbry.github.io/VaxNear/privacy-policy.html")!
    private let termsOfServiceURL = URL(string: "https://chadnewbry.github.io/VaxNear/terms-of-service.html")!
    private let supportURL = URL(string: "https://chadnewbry.github.io/VaxNear/support.html")!

    var body: some View {
        NavigationStack {
            List {
                Section("Security") {
                    Toggle("Require Face ID", systemImage: "faceid", isOn: $isBiometricLockEnabled)
                }

                Section("Data") {
                    Label("iCloud Sync", systemImage: "icloud")
                    Label("Export Records", systemImage: "square.and.arrow.up")
                    Label("HealthKit", systemImage: "heart.text.square")
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
