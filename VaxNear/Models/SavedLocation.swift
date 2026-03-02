import Foundation
import SwiftData

@Model
final class SavedLocation {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var phoneNumber: String?
    var vaccineTypesAvailable: [String] = []
    var isWalkIn: Bool = false
    var isFavorite: Bool = false

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
