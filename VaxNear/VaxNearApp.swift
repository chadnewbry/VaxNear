import SwiftData
import SwiftUI

@main
struct VaxNearApp: App {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false
    @State private var isUnlocked = false
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var syncManager = SyncManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FamilyProfile.self,
            VaccinationRecord.self,
            SideEffectLog.self,
            SavedLocation.self,
            TravelPlan.self,
            AppSettings.self,
            ScheduledReminder.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if isBiometricLockEnabled && !isUnlocked {
                    LockScreenView(isUnlocked: $isUnlocked)
                } else {
                    MainTabView()
                }
            }
            .onAppear {
                notificationManager.configure(modelContext: sharedModelContainer.mainContext)
                Task {
                    await notificationManager.requestPermission()
                    notificationManager.scheduleSeasonalAlerts()
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(notificationManager)
        .environmentObject(syncManager)
    }
}
