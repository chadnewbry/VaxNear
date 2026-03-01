import Foundation
import SwiftData

@Model
final class SavedLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var phoneNumber: String?
    var vaccineTypesAvailable: [String]
    var isWalkIn: Bool
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        phoneNumber: String? = nil,
        vaccineTypesAvailable: [String] = [],
        isWalkIn: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.vaccineTypesAvailable = vaccineTypesAvailable
        self.isWalkIn = isWalkIn
        self.isFavorite = isFavorite
    }
}
