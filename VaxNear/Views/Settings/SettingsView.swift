import SwiftUI

struct SettingsView: View {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false

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
                    Label("Privacy Policy", systemImage: "hand.raised")
                    Label("Terms of Service", systemImage: "doc.text")
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
