import Foundation
import SwiftData

@Model
final class TravelPlan {
    @Attribute(.unique) var id: UUID
    var profile: FamilyProfile?
    var destination: String
    var countryCode: String
    var departureDate: Date
    var requiredVaccines: [String]
    var recommendedVaccines: [String]
    var completedVaccines: [String]

    init(
        id: UUID = UUID(),
        profile: FamilyProfile? = nil,
        destination: String,
        countryCode: String,
        departureDate: Date,
        requiredVaccines: [String] = [],
        recommendedVaccines: [String] = [],
        completedVaccines: [String] = []
    ) {
        self.id = id
        self.profile = profile
        self.destination = destination
        self.countryCode = countryCode
        self.departureDate = departureDate
        self.requiredVaccines = requiredVaccines
        self.recommendedVaccines = recommendedVaccines
        self.completedVaccines = completedVaccines
    }
}
