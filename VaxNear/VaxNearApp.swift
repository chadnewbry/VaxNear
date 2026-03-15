import SwiftData
import SwiftUI

@main
struct VaxNearApp: App {
    @AppStorage("isBiometricLockEnabled") private var isBiometricLockEnabled = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
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
            let url = config.url
            let related = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            for file in related {
                try? FileManager.default.removeItem(at: file)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        #if DEBUG
        if ScreenshotSampleData.isScreenshotMode {
            let context = sharedModelContainer.mainContext
            ScreenshotSampleData.populate(context: context)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView()
                } else if isBiometricLockEnabled && !isUnlocked {
                    LockScreenView(isUnlocked: $isUnlocked)
                } else {
                    MainTabView()
                }
            }
            .onAppear {
                notificationManager.configure(modelContext: sharedModelContainer.mainContext)
                if hasCompletedOnboarding {
                    Task {
                        _ = await notificationManager.requestPermission()
                        notificationManager.scheduleSeasonalAlerts()
                        WidgetDataProvider(context: sharedModelContainer.mainContext).updateWidgetData()
                    }
                }
            }
            .onOpenURL { url in
                if let deepLink = DeepLink.from(url: url) {
                    NavigationState.shared.handle(deepLink)
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(notificationManager)
        .environmentObject(syncManager)
    }
}
