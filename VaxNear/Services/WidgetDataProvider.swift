import Foundation
import SwiftData
import WidgetKit

final class WidgetDataProvider {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func updateWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group." + AppConfig.shared.bundleId) else { return }

        let now = Date()
        let descriptor = FetchDescriptor<ScheduledReminder>(
            predicate: #Predicate { $0.scheduledDate > now },
            sortBy: [SortDescriptor(\ScheduledReminder.scheduledDate)]
        )

        guard let reminders = try? context.fetch(descriptor), let next = reminders.first else {
            defaults.removeObject(forKey: "nextDueVaccine")
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let profileDescriptor = FetchDescriptor<FamilyProfile>()
        let profiles = (try? context.fetch(profileDescriptor)) ?? []
        let profile = profiles.first(where: { $0.id == next.profileId })

        if let primaryProfile = profiles.first(where: { $0.relationship == .selfUser }) ?? profiles.first {
            defaults.set(primaryProfile.name, forKey: "primaryProfileName")
        }

        let data = NextDueData(
            vaccineName: next.title,
            dueDate: next.scheduledDate,
            recordId: nil
        )

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: "nextDueVaccine")
            if let profileName = profile?.name {
                defaults.set(encoded, forKey: "nextDueVaccine_\(profileName)")
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct NextDueData: Codable {
    let vaccineName: String
    let dueDate: Date
    let recordId: UUID?
}
