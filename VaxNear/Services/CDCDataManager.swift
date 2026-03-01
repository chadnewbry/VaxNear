import Foundation

// MARK: - CDC Data Transfer Objects

struct ChildhoodVaccine: Codable {
    let vaccineName: String
    let doses: [DoseSchedule]
    let notes: String

    struct DoseSchedule: Codable {
        let doseNumber: Int
        let ageRangeMonths: AgeRange
        let catchUpAgeMonths: Int?

        struct AgeRange: Codable {
            let min: Int
            let max: Int
        }
    }
}

struct AdultVaccine: Codable {
    let vaccineName: String
    let recommendedFor: [Recommendation]
    let boosterIntervalMonths: Int?
    let notes: String

    struct Recommendation: Codable {
        let minAge: Int
        let maxAge: Int?
        let conditions: [String]
    }
}

struct TravelVaccineEntry: Codable {
    let countryCode: String
    let countryName: String
    let required: [String]
    let recommended: [String]
    let malariaRisk: Bool
    let yellowFeverCertRequired: Bool
    let notes: String
}

struct VaccineDBEntry: Codable {
    let name: String
    let alternateNames: [String]
    let manufacturer: String
    let type: String
    let typicalBoosterIntervalMonths: Int?
}

// MARK: - Public Result Types

struct RecommendedVaccine {
    let vaccineName: String
    let doseNumber: Int?
    let notes: String
}

struct TravelVaccineInfo {
    let countryCode: String
    let countryName: String
    let required: [String]
    let recommended: [String]
    let malariaRisk: Bool
    let yellowFeverCertRequired: Bool
    let notes: String
}

struct VaccineInfo {
    let name: String
    let alternateNames: [String]
    let manufacturer: String
    let type: String
    let typicalBoosterIntervalMonths: Int?
}

// MARK: - CDCDataManager

final class CDCDataManager: Sendable {
    static let shared = CDCDataManager()

    private let childhoodSchedule: [ChildhoodVaccine]
    private let adultScheduleData: [AdultVaccine]
    private let travelData: [TravelVaccineEntry]
    private let vaccineDB: [VaccineDBEntry]

    private init() {
        self.childhoodSchedule = Self.load("childhood_schedule")
        self.adultScheduleData = Self.load("adult_schedule")
        self.travelData = Self.load("travel_vaccines")
        self.vaccineDB = Self.load("vaccine_database")
    }

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "CDCData"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Queries

    func childSchedule(forAgeMonths ageMonths: Int) -> [RecommendedVaccine] {
        childhoodSchedule.flatMap { vaccine in
            vaccine.doses.compactMap { dose in
                let isDue = ageMonths >= dose.ageRangeMonths.min && ageMonths <= dose.ageRangeMonths.max
                let isCatchUp = dose.catchUpAgeMonths.map { ageMonths <= $0 && ageMonths > dose.ageRangeMonths.max } ?? false
                guard isDue || isCatchUp else { return nil as RecommendedVaccine? }
                return RecommendedVaccine(
                    vaccineName: vaccine.vaccineName,
                    doseNumber: dose.doseNumber,
                    notes: isDue ? vaccine.notes : "Catch-up dose. \(vaccine.notes)"
                )
            }
        }
    }

    func adultSchedule(forAge age: Int) -> [RecommendedVaccine] {
        adultScheduleData.compactMap { vaccine in
            let applicable = vaccine.recommendedFor.contains { rec in
                age >= rec.minAge && (rec.maxAge == nil || age <= rec.maxAge!)
            }
            guard applicable else { return nil }
            return RecommendedVaccine(
                vaccineName: vaccine.vaccineName,
                doseNumber: nil,
                notes: vaccine.notes
            )
        }
    }

    func travelVaccines(forCountryCode code: String) -> TravelVaccineInfo? {
        guard let entry = travelData.first(where: { $0.countryCode.uppercased() == code.uppercased() }) else {
            return nil
        }
        return TravelVaccineInfo(
            countryCode: entry.countryCode,
            countryName: entry.countryName,
            required: entry.required,
            recommended: entry.recommended,
            malariaRisk: entry.malariaRisk,
            yellowFeverCertRequired: entry.yellowFeverCertRequired,
            notes: entry.notes
        )
    }

    func allVaccines() -> [VaccineInfo] {
        vaccineDB.map { entry in
            VaccineInfo(
                name: entry.name,
                alternateNames: entry.alternateNames,
                manufacturer: entry.manufacturer,
                type: entry.type,
                typicalBoosterIntervalMonths: entry.typicalBoosterIntervalMonths
            )
        }
    }

    func searchVaccines(query: String) -> [VaccineInfo] {
        let q = query.lowercased()
        return allVaccines().filter { vaccine in
            vaccine.name.lowercased().contains(q) ||
            vaccine.alternateNames.contains { $0.lowercased().contains(q) } ||
            vaccine.manufacturer.lowercased().contains(q) ||
            vaccine.type.lowercased().contains(q)
        }
    }

    func nextBoosterDue(for vaccineName: String, lastDoseDate: Date) -> Date? {
        guard let entry = vaccineDB.first(where: { $0.name.lowercased() == vaccineName.lowercased() }),
              let intervalMonths = entry.typicalBoosterIntervalMonths else {
            return nil
        }
        return Calendar.current.date(byAdding: .month, value: intervalMonths, to: lastDoseDate)
    }
}
