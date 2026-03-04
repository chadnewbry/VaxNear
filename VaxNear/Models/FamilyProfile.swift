import Foundation
import SwiftData

enum Relationship: String, Codable, CaseIterable, Identifiable {
    case selfUser = "self"
    case spouse
    case son
    case daughter
    case child
    case parent
    case grandparent
    case sibling
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfUser: return "Self"
        case .spouse: return "Spouse"
        case .son: return "Son"
        case .daughter: return "Daughter"
        case .child: return "Child"
        case .parent: return "Parent"
        case .grandparent: return "Grandparent"
        case .sibling: return "Sibling"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .selfUser: return "person.fill"
        case .spouse: return "heart.fill"
        case .son, .daughter, .child: return "figure.child"
        case .parent: return "figure.and.child.holdinghands"
        case .grandparent: return "figure.2"
        case .sibling: return "person.2.fill"
        case .other: return "person.fill.questionmark"
        }
    }

    /// Whether this relationship represents a child (for immunization schedule purposes)
    var isChild: Bool {
        switch self {
        case .son, .daughter, .child: return true
        default: return false
        }
    }
}

enum BloodType: String, Codable, CaseIterable, Identifiable {
    case unknown = "Unknown"
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"

    var id: String { rawValue }
}

@Model
final class FamilyProfile {
    var id: UUID = UUID()
    var name: String = ""
    var relationshipRawValue: String = Relationship.selfUser.rawValue
    var dateOfBirth: Date = Date()
    var colorTag: String = "#007AFF"
    var createdAt: Date = Date()

    // Additional tracking fields
    var allergies: String = ""
    var bloodTypeRawValue: String = BloodType.unknown.rawValue
    var medicalNotes: String = ""
    var emergencyContact: String = ""
    var insuranceInfo: String = ""

    @Transient var relationship: Relationship {
        get { Relationship(rawValue: relationshipRawValue) ?? .selfUser }
        set { relationshipRawValue = newValue.rawValue }
    }

    @Transient var bloodType: BloodType {
        get { BloodType(rawValue: bloodTypeRawValue) ?? .unknown }
        set { bloodTypeRawValue = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \VaccinationRecord.profile)
    var _vaccinationRecords: [VaccinationRecord]?

    @Relationship(deleteRule: .cascade, inverse: \TravelPlan.profile)
    var _travelPlans: [TravelPlan]?

    @Transient var vaccinationRecords: [VaccinationRecord] {
        get { _vaccinationRecords ?? [] }
        set { _vaccinationRecords = newValue }
    }

    @Transient var travelPlans: [TravelPlan] {
        get { _travelPlans ?? [] }
        set { _travelPlans = newValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        relationship: Relationship,
        dateOfBirth: Date,
        colorTag: String = "#007AFF",
        createdAt: Date = Date(),
        allergies: String = "",
        bloodType: BloodType = .unknown,
        medicalNotes: String = "",
        emergencyContact: String = "",
        insuranceInfo: String = ""
    ) {
        self.id = id
        self.name = name
        self.relationshipRawValue = relationship.rawValue
        self.dateOfBirth = dateOfBirth
        self.colorTag = colorTag
        self.createdAt = createdAt
        self.allergies = allergies
        self.bloodTypeRawValue = bloodType.rawValue
        self.medicalNotes = medicalNotes
        self.emergencyContact = emergencyContact
        self.insuranceInfo = insuranceInfo
    }

    var ageInMonths: Int {
        Calendar.current.dateComponents([.month], from: dateOfBirth, to: Date()).month ?? 0
    }

    var ageInYears: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
}
