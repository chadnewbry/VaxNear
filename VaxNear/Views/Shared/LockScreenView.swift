import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Binding var isUnlocked: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("VaxNear is Locked")
                .font(.title2.bold())

            Text("Authenticate to access your vaccination records")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Unlock") {
                authenticate()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear { authenticate() }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock VaxNear") { success, _ in
                if success {
                    DispatchQueue.main.async { isUnlocked = true }
                }
            }
        } else {
            isUnlocked = true
        }
    }
}
