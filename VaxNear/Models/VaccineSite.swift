import CoreLocation
import Foundation

struct VaccineSite: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    var distance: Double? // miles
    let phoneNumber: String?
    let category: Category
    var isWalkIn: Bool = false
    var operatingHours: String?
    var appointmentURL: URL?

    enum Category: String, CaseIterable, Identifiable {
        case pharmacy
        case clinic
        case hospital
        case healthDept

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .pharmacy: "Pharmacy"
            case .clinic: "Clinic / Urgent Care"
            case .hospital: "Hospital"
            case .healthDept: "Health Department"
            }
        }

        var systemImage: String {
            switch self {
            case .pharmacy: "cross.case.fill"
            case .clinic: "stethoscope"
            case .hospital: "building.2.fill"
            case .healthDept: "heart.text.square.fill"
            }
        }
    }

    static func == (lhs: VaccineSite, rhs: VaccineSite) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Vaccine Type Filter

enum VaccineTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case covid = "COVID-19"
    case flu = "Flu"
    case travel = "Travel"

    var id: String { rawValue }

    /// Search terms to use with MKLocalSearch for this vaccine type.
    var searchQueries: [String] {
        switch self {
        case .all:
            return ["pharmacy", "health clinic", "hospital", "health department"]
        case .covid:
            return ["pharmacy", "COVID vaccine", "health clinic"]
        case .flu:
            return ["pharmacy", "flu shot", "health clinic"]
        case .travel:
            return ["travel clinic", "pharmacy", "hospital", "health department"]
        }
    }
}
