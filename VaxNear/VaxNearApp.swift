import SwiftData
import SwiftUI

@main
struct VaxNearApp: App {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false
    @State private var isUnlocked = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FamilyProfile.self,
            VaccinationRecord.self,
            SideEffectLog.self,
            SavedLocation.self,
            TravelPlan.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if isBiometricLockEnabled && !isUnlocked {
                LockScreenView(isUnlocked: $isUnlocked)
            } else {
                MainTabView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
