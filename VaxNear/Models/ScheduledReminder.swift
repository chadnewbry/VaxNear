import Foundation
import SwiftData

enum ReminderType: String, Codable {
    case booster
    case appointment
    case seasonal
    case childMilestone
}

@Model
final class ScheduledReminder {
    var id: String = UUID().uuidString
    var profileId: UUID = UUID()
    var typeRawValue: String = ReminderType.booster.rawValue
    var scheduledDate: Date = Date()
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date()

    @Transient var type: ReminderType {
        get { ReminderType(rawValue: typeRawValue) ?? .booster }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        profileId: UUID,
        type: ReminderType,
        scheduledDate: Date,
        title: String,
        body: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.profileId = profileId
        self.typeRawValue = type.rawValue
        self.scheduledDate = scheduledDate
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
