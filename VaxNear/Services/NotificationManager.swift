import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private let cdcManager = CDCDataManager.shared

    private var modelContext: ModelContext?

    init() {
        Task { await checkAuthorizationStatus() }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            return granted
        } catch {
            print("NotificationManager: permission error — \(error.localizedDescription)")
            return false
        }
    }

    private func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Booster Reminders

    func scheduleBoosterReminder(for record: VaccinationRecord) {
        guard let context = modelContext else { return }
        let settings = AppSettings.shared(in: context)

        guard let boosterDate = cdcManager.nextBoosterDue(
            for: record.vaccineName,
            lastDoseDate: record.dateAdministered
        ) else { return }

        let calendar = Calendar.current
        let noticeDate = calendar.date(
            byAdding: .day,
            value: -settings.notificationAdvanceDays,
            to: boosterDate
        ) ?? boosterDate
        let adjustedDate = adjustForQuietHours(noticeDate, settings: settings)

        guard adjustedDate > .now else { return }

        let formatter = DateFormatter()
        formatter.dateStyle = .long

        let identifier = "booster-\(record.id.uuidString)"
        let body = "Your \(record.vaccineName) booster is due on \(formatter.string(from: boosterDate)). Open VaxNear to find a nearby vaccination site."

        scheduleNotification(
            identifier: identifier,
            title: "Booster Reminder",
            body: body,
            date: adjustedDate,
            userInfo: ["type": "booster", "recordId": record.id.uuidString]
        )

        let profileId = record.profile?.id ?? UUID()
        saveReminder(
            id: identifier,
            profileId: profileId,
            type: .booster,
            date: adjustedDate,
            title: "Booster Reminder",
            body: body,
            in: context
        )
    }

    // MARK: - Appointment Reminders

    func scheduleAppointmentReminder(date: Date, location: String, notes: String = "") {
        guard let context = modelContext else { return }
        let settings = AppSettings.shared(in: context)

        let adjustedDate = adjustForQuietHours(date, settings: settings)
        guard adjustedDate > .now else { return }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let identifier = "appointment-\(UUID().uuidString)"
        let body = "Vaccination appointment today at \(location) at \(timeFormatter.string(from: date))"
        let fullBody = notes.isEmpty ? body : "\(body)\n\(notes)"

        scheduleNotification(
            identifier: identifier,
            title: "Appointment Reminder",
            body: fullBody,
            date: adjustedDate,
            userInfo: ["type": "appointment"]
        )

        saveReminder(
            id: identifier,
            profileId: UUID(),
            type: .appointment,
            date: adjustedDate,
            title: "Appointment Reminder",
            body: body,
            in: context
        )
    }

    // MARK: - Child Milestone Reminders

    func scheduleChildMilestoneReminders(for profile: FamilyProfile) {
        guard let context = modelContext,
              profile.relationship.isChild else { return }

        // Cancel existing milestone reminders for this profile
        cancelReminders(for: profile.id, ofType: .childMilestone, in: context)

        let settings = AppSettings.shared(in: context)
        let calendar = Calendar.current
        let ageMonths = profile.ageInMonths

        // Look ahead at milestones for the next 6 months
        let upcomingVaccines = cdcManager.childSchedule(forAgeMonths: ageMonths)

        // Also check the next couple of milestone windows
        let futureChecks = [ageMonths + 1, ageMonths + 2, ageMonths + 3, ageMonths + 4, ageMonths + 5, ageMonths + 6]
        var allVaccines = upcomingVaccines
        for futureAge in futureChecks {
            let vaccines = cdcManager.childSchedule(forAgeMonths: futureAge)
            for v in vaccines where !allVaccines.contains(where: { $0.vaccineName == v.vaccineName && $0.doseNumber == v.doseNumber }) {
                allVaccines.append(v)
            }
        }

        // Group by approximate age milestone
        let milestoneAges = Set(futureChecks + [ageMonths])
        for targetAge in milestoneAges.sorted() {
            let vaccinesAtAge = cdcManager.childSchedule(forAgeMonths: targetAge)
            guard !vaccinesAtAge.isEmpty else { continue }

            let milestoneDate = calendar.date(byAdding: .month, value: targetAge - ageMonths, to: .now) ?? .now
            let noticeDate = calendar.date(
                byAdding: .day,
                value: -settings.notificationAdvanceDays,
                to: milestoneDate
            ) ?? milestoneDate
            let adjustedDate = adjustForQuietHours(noticeDate, settings: settings)

            guard adjustedDate > .now else { continue }

            let vaccineList = vaccinesAtAge.map(\.vaccineName).joined(separator: ", ")
            let identifier = "milestone-\(profile.id.uuidString)-\(targetAge)"
            let ageLabel = targetAge < 24 ? "\(targetAge) months" : "\(targetAge / 12) years"
            let body = "\(profile.name) is turning \(ageLabel) — \(vaccineList) vaccines are due"

            scheduleNotification(
                identifier: identifier,
                title: "Vaccine Milestone",
                body: body,
                date: adjustedDate,
                userInfo: ["type": "childMilestone", "profileId": profile.id.uuidString]
            )

            saveReminder(
                id: identifier,
                profileId: profile.id,
                type: .childMilestone,
                date: adjustedDate,
                title: "Vaccine Milestone",
                body: body,
                in: context
            )
        }
    }

    // MARK: - Seasonal Vaccine Alerts

    func scheduleSeasonalAlerts() {
        guard let context = modelContext else { return }
        let settings = AppSettings.shared(in: context)
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)

        for year in [currentYear, currentYear + 1] {
            scheduleFluReminder(year: year, settings: settings, context: context)
            scheduleCOVIDBoosterReminder(year: year, settings: settings, context: context)
        }
    }

    private func scheduleFluReminder(year: Int, settings: AppSettings, context: ModelContext) {
        var components = DateComponents()
        components.year = year
        components.month = 9
        components.day = 1
        components.hour = 10

        guard let date = Calendar.current.date(from: components), date > .now else { return }

        let adjustedDate = adjustForQuietHours(date, settings: settings)
        let identifier = "seasonal-flu-\(year)"
        let body = "It's flu season! Time to get your annual flu shot. Open VaxNear to find a nearby vaccination site."

        scheduleNotification(
            identifier: identifier,
            title: "Flu Season Reminder",
            body: body,
            date: adjustedDate,
            userInfo: ["type": "seasonal"]
        )

        saveReminder(
            id: identifier,
            profileId: UUID(),
            type: .seasonal,
            date: adjustedDate,
            title: "Flu Season Reminder",
            body: body,
            in: context
        )
    }

    private func scheduleCOVIDBoosterReminder(year: Int, settings: AppSettings, context: ModelContext) {
        var components = DateComponents()
        components.year = year
        components.month = 10
        components.day = 1
        components.hour = 10

        guard let date = Calendar.current.date(from: components), date > .now else { return }

        let adjustedDate = adjustForQuietHours(date, settings: settings)
        let identifier = "seasonal-covid-\(year)"
        let body = "Updated COVID-19 boosters are typically available now. Open VaxNear to find a nearby vaccination site."

        scheduleNotification(
            identifier: identifier,
            title: "COVID Booster Available",
            body: body,
            date: adjustedDate,
            userInfo: ["type": "seasonal"]
        )

        saveReminder(
            id: identifier,
            profileId: UUID(),
            type: .seasonal,
            date: adjustedDate,
            title: "COVID Booster Available",
            body: body,
            in: context
        )
    }

    // MARK: - Refresh & Cancel

    /// Recalculate all pending notifications. Caller should pass current records and profiles
    /// to re-trigger booster and milestone reminders after this clears everything.
    func refreshAllReminders() {
        guard let context = modelContext else { return }

        center.removeAllPendingNotificationRequests()

        let descriptor = FetchDescriptor<ScheduledReminder>()
        if let existing = try? context.fetch(descriptor) {
            for reminder in existing {
                context.delete(reminder)
            }
        }
        try? context.save()

        // Re-schedule seasonal alerts
        scheduleSeasonalAlerts()
    }

    func cancelAllReminders(for profileId: UUID) {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ScheduledReminder>(
            predicate: #Predicate<ScheduledReminder> { $0.profileId == profileId }
        )
        if let reminders = try? context.fetch(descriptor) {
            let identifiers = reminders.map(\.id)
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            for reminder in reminders {
                context.delete(reminder)
            }
        }
        try? context.save()
    }

    func pendingReminders() -> [ScheduledReminder] {
        guard let context = modelContext else { return [] }
        let now = Date.now
        let descriptor = FetchDescriptor<ScheduledReminder>(
            predicate: #Predicate<ScheduledReminder> { $0.scheduledDate > now },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private Helpers

    private func adjustForQuietHours(_ date: Date, settings: AppSettings) -> Date {
        guard let start = settings.quietHoursStart,
              let end = settings.quietHoursEnd else { return date }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let startHour = calendar.component(.hour, from: start)
        let endHour = calendar.component(.hour, from: end)

        let inQuietHours: Bool
        if startHour > endHour {
            inQuietHours = hour >= startHour || hour < endHour
        } else {
            inQuietHours = hour >= startHour && hour < endHour
        }

        guard inQuietHours else { return date }

        // Push to end of quiet hours
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endHour
        components.minute = 0

        if let adjusted = calendar.date(from: components) {
            return adjusted < date
                ? calendar.date(byAdding: .day, value: 1, to: adjusted) ?? date
                : adjusted
        }
        return date
    }

    private func cancelReminders(for profileId: UUID, ofType type: ReminderType, in context: ModelContext) {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<ScheduledReminder>(
            predicate: #Predicate<ScheduledReminder> {
                $0.profileId == profileId && $0.typeRawValue == typeRaw
            }
        )
        if let reminders = try? context.fetch(descriptor) {
            let identifiers = reminders.map(\.id)
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            for reminder in reminders {
                context.delete(reminder)
            }
        }
        try? context.save()
    }

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        date: Date,
        userInfo: [String: String]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func saveReminder(
        id: String,
        profileId: UUID,
        type: ReminderType,
        date: Date,
        title: String,
        body: String,
        in context: ModelContext
    ) {
        // Remove existing with same id
        let descriptor = FetchDescriptor<ScheduledReminder>(
            predicate: #Predicate<ScheduledReminder> { $0.id == id }
        )
        if let existing = try? context.fetch(descriptor) {
            for r in existing { context.delete(r) }
        }

        let reminder = ScheduledReminder(
            id: id,
            profileId: profileId,
            type: type,
            scheduledDate: date,
            title: title,
            body: body
        )
        context.insert(reminder)
        try? context.save()
    }
}
