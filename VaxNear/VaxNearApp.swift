import SwiftUI

@main
struct VaxNearApp: App {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false
    @State private var isUnlocked = false

    var body: some Scene {
        WindowGroup {
            if isBiometricLockEnabled && !isUnlocked {
                LockScreenView(isUnlocked: $isUnlocked)
            } else {
                MainTabView()
            }
        }
    }
}
