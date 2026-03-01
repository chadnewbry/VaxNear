import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var searchRadiusMiles: Int
    var notificationAdvanceDays: Int
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
    var isBiometricLockEnabled: Bool
    var freeUsesRemaining: Int
    var hasPurchasedFullVersion: Bool

    init(
        id: UUID = UUID(),
        searchRadiusMiles: Int = 25,
        notificationAdvanceDays: Int = 7,
        quietHoursStart: Date? = nil,
        quietHoursEnd: Date? = nil,
        isBiometricLockEnabled: Bool = false,
        freeUsesRemaining: Int = 5,
        hasPurchasedFullVersion: Bool = false
    ) {
        self.id = id
        self.searchRadiusMiles = searchRadiusMiles
        self.notificationAdvanceDays = notificationAdvanceDays
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.isBiometricLockEnabled = isBiometricLockEnabled
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
