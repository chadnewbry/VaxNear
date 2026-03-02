import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var authError: String?
    @State private var showPasscodeOption = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: biometricIconName)
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text("VaxNear is Locked")
                .font(.title2.bold())

            Text("Authenticate to access your vaccination records")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let authError {
                Text(authError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Unlock with \(biometricLabel)") {
                authenticateWithBiometrics()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Authenticate to access your vaccination records")

            if showPasscodeOption {
                Button("Use Device Passcode") {
                    authenticateWithPasscode()
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear {
            checkBiometricAvailability()
            authenticateWithBiometrics()
        }
    }

    private var biometricIconName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.shield"
        }
    }

    private var biometricLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            showPasscodeOption = true
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Device Passcode"
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock VaxNear") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isUnlocked = true
                    } else {
                        showPasscodeOption = true
                        if let laError = authenticationError as? LAError {
                            if laError.code == .userFallback {
                                authenticateWithPasscode()
                            } else if laError.code != .userCancel {
                                authError = "Biometric authentication failed. Use your device passcode instead."
                            }
                        }
                    }
                }
            }
        } else {
            showPasscodeOption = true
            authenticateWithPasscode()
        }
    }

    private func authenticateWithPasscode() {
        let context = LAContext()

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock VaxNear with your device passcode") { success, error in
            DispatchQueue.main.async {
                if success {
                    isUnlocked = true
                } else if let error = error as? LAError, error.code != .userCancel {
                    authError = "Authentication failed. Please try again."
                }
            }
        }
    }
}
