import Foundation
import SwiftData

@Model
final class VaccinationRecord {
    var id: UUID = UUID()
    var profile: FamilyProfile?
    var vaccineName: String = ""
    var manufacturer: String?
    var lotNumber: String?
    var dateAdministered: Date = Date()
    var administeringProvider: String?
    var injectionSite: String?
    var notes: String?
    var smartHealthCardData: Data?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SideEffectLog.record)
    var sideEffects: [SideEffectLog] = []

    init(
        id: UUID = UUID(),
        profile: FamilyProfile? = nil,
        vaccineName: String,
        manufacturer: String? = nil,
        lotNumber: String? = nil,
        dateAdministered: Date,
        administeringProvider: String? = nil,
        injectionSite: String? = nil,
        notes: String? = nil,
        smartHealthCardData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.profile = profile
        self.vaccineName = vaccineName
        self.manufacturer = manufacturer
        self.lotNumber = lotNumber
        self.dateAdministered = dateAdministered
        self.administeringProvider = administeringProvider
        self.injectionSite = injectionSite
        self.notes = notes
        self.smartHealthCardData = smartHealthCardData
        self.createdAt = createdAt
    }
}
