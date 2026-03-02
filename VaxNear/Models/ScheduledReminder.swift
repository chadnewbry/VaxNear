import Foundation
import SwiftData

@Model
final class ScheduledReminder {
    var id: String = UUID().uuidString
    var profileId: UUID = UUID()
    var type: ReminderType = .booster
    var scheduledDate: Date = Date()
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date()

    enum ReminderType: String, Codable {
        case booster
        case appointment
        case seasonal
        case childMilestone
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
        self.type = type
        self.scheduledDate = scheduledDate
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
