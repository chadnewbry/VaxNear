import Foundation
import SwiftData

enum Relationship: String, Codable, CaseIterable, Identifiable {
    case selfUser = "self"
    case spouse
    case child
    case parent
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfUser: return "Self"
        case .spouse: return "Spouse"
        case .child: return "Child"
        case .parent: return "Parent"
        case .other: return "Other"
        }
    }
}

@Model
final class FamilyProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var relationship: Relationship
    var dateOfBirth: Date
    var colorTag: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \VaccinationRecord.profile)
    var vaccinationRecords: [VaccinationRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \TravelPlan.profile)
    var travelPlans: [TravelPlan] = []

    init(
        id: UUID = UUID(),
        name: String,
        relationship: Relationship,
        dateOfBirth: Date,
        colorTag: String = "#007AFF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.dateOfBirth = dateOfBirth
        self.colorTag = colorTag
        self.createdAt = createdAt
    }

    var ageInMonths: Int {
        Calendar.current.dateComponents([.month], from: dateOfBirth, to: Date()).month ?? 0
    }

    var ageInYears: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}
