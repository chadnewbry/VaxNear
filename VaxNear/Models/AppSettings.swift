import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID = UUID()
    var searchRadiusMiles: Int = 25
    var defaultVaccineTypeFilter: String = ""
    var notificationAdvanceDays: Int = 7
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
    var boosterRemindersEnabled: Bool = true
    var seasonalAlertsEnabled: Bool = true
    var childMilestoneNotificationsEnabled: Bool = true
    var isBiometricLockEnabled: Bool = false
    var isICloudSyncEnabled: Bool = true
    var freeUsesRemaining: Int = 5
    var hasPurchasedFullVersion: Bool = false

    init(
        id: UUID = UUID(),
        searchRadiusMiles: Int = 25,
        defaultVaccineTypeFilter: String = "",
        notificationAdvanceDays: Int = 7,
        quietHoursStart: Date? = nil,
        quietHoursEnd: Date? = nil,
        boosterRemindersEnabled: Bool = true,
        seasonalAlertsEnabled: Bool = true,
        childMilestoneNotificationsEnabled: Bool = true,
        isBiometricLockEnabled: Bool = false,
        isICloudSyncEnabled: Bool = true,
        freeUsesRemaining: Int = 5,
        hasPurchasedFullVersion: Bool = false
    ) {
        self.id = id
        self.searchRadiusMiles = searchRadiusMiles
        self.defaultVaccineTypeFilter = defaultVaccineTypeFilter
        self.notificationAdvanceDays = notificationAdvanceDays
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.boosterRemindersEnabled = boosterRemindersEnabled
        self.seasonalAlertsEnabled = seasonalAlertsEnabled
        self.childMilestoneNotificationsEnabled = childMilestoneNotificationsEnabled
        self.isBiometricLockEnabled = isBiometricLockEnabled
        self.isICloudSyncEnabled = isICloudSyncEnabled
        self.freeUsesRemaining = freeUsesRemaining
        self.hasPurchasedFullVersion = hasPurchasedFullVersion
    }

    static func shared(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
