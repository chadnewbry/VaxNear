import Foundation
import SwiftData
import SwiftUI

// MARK: - Vaccine Status

enum VaccineStatus {
    case upToDate
    case boosterDue
    case missing

    var color: Color {
        switch self {
        case .upToDate: return .green
        case .boosterDue: return .orange
        case .missing: return .red
        }
    }

    var icon: String {
        switch self {
        case .upToDate: return "checkmark.circle.fill"
        case .boosterDue: return "exclamationmark.triangle.fill"
        case .missing: return "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .upToDate: return "Up to date"
        case .boosterDue: return "Booster due"
        case .missing: return "Missing"
        }
    }
}

struct TravelVaccineRow: Identifiable {
    let id = UUID()
    let vaccineName: String
    let status: VaccineStatus
    let lastDoseDate: Date?
    let boosterDueDate: Date?
}

struct TimelineItem: Identifiable {
    let id = UUID()
    let vaccineName: String
    let doseLabel: String
    let suggestedDate: Date
    let weeksBeforeDeparture: Int
}

// MARK: - ViewModel

@MainActor
final class TravelViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCountry: TravelVaccineInfo?
    @Published var recentDestinations: [TravelVaccineInfo] = []
    @Published var requiredVaccineRows: [TravelVaccineRow] = []
    @Published var recommendedVaccineRows: [TravelVaccineRow] = []
    @Published var showingTimeline = false
    @Published var departureDate = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @Published var timelineItems: [TimelineItem] = []
    @Published var activeTravelPlan: TravelPlan?
    @Published var showingYellowCard = false

    private let cdcManager = CDCDataManager.shared

    var filteredCountries: [TravelVaccineInfo] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return allCountries.filter {
            $0.countryName.lowercased().contains(q) || $0.countryCode.lowercased().contains(q)
        }
    }

    private var allCountries: [TravelVaccineInfo] {
        cdcManager.allTravelCountries()
    }

    func loadRecentDestinations(from plans: [TravelPlan]) {
        var seen = Set<String>()
        recentDestinations = plans
            .sorted(by: { $0.departureDate > $1.departureDate })
            .compactMap { plan -> TravelVaccineInfo? in
                guard seen.insert(plan.countryCode).inserted else { return nil }
                return cdcManager.travelVaccines(forCountryCode: plan.countryCode)
            }
            .prefix(5)
            .map { $0 }
    }

    func selectCountry(_ country: TravelVaccineInfo, records: [VaccinationRecord]) {
        selectedCountry = country
        showingTimeline = false
        analyzeGap(records: records)
    }

    func analyzeGap(records: [VaccinationRecord]) {
        guard let country = selectedCountry else { return }

        func statusFor(_ vaccineName: String) -> TravelVaccineRow {
            let matchingRecords = records.filter { matchesVaccine($0.vaccineName, vaccineName) }
                .sorted(by: { $0.dateAdministered > $1.dateAdministered })

            guard let latest = matchingRecords.first else {
                return TravelVaccineRow(vaccineName: vaccineName, status: .missing, lastDoseDate: nil, boosterDueDate: nil)
            }

            if let boosterDate = cdcManager.nextBoosterDue(for: vaccineName, lastDoseDate: latest.dateAdministered),
               boosterDate < Date() {
                return TravelVaccineRow(vaccineName: vaccineName, status: .boosterDue, lastDoseDate: latest.dateAdministered, boosterDueDate: boosterDate)
            }

            return TravelVaccineRow(vaccineName: vaccineName, status: .upToDate, lastDoseDate: latest.dateAdministered, boosterDueDate: nil)
        }

        requiredVaccineRows = country.required.map { statusFor($0) }
        recommendedVaccineRows = country.recommended.map { statusFor($0) }
    }

    func generateTimeline() {
        guard selectedCountry != nil else { return }
        showingTimeline = true

        let allNeeded = (requiredVaccineRows + recommendedVaccineRows).filter { $0.status != .upToDate }
        var items: [TimelineItem] = []

        let leadTimes: [String: [Int]] = [
            "Yellow Fever": [4],
            "Hepatitis A": [8, 4],
            "Hepatitis B": [8, 4, 0],
            "Typhoid": [2],
            "Japanese Encephalitis": [4, 3],
            "Rabies": [4, 3, 1],
            "Meningococcal": [2],
            "Meningococcal ACWY": [2],
            "Cholera": [3, 2],
        ]

        for row in allNeeded {
            let baseName = row.vaccineName
            let weeks = leadTimes[baseName] ?? [4]

            for (index, weeksBefore) in weeks.enumerated() {
                let suggestedDate = Calendar.current.date(byAdding: .weekOfYear, value: -weeksBefore, to: departureDate) ?? departureDate
                let doseLabel = weeks.count > 1 ? "Dose \(index + 1) of \(weeks.count)" : (row.status == .boosterDue ? "Booster" : "Single dose")
                items.append(TimelineItem(
                    vaccineName: baseName,
                    doseLabel: doseLabel,
                    suggestedDate: suggestedDate,
                    weeksBeforeDeparture: weeksBefore
                ))
            }
        }

        timelineItems = items.sorted(by: { $0.suggestedDate < $1.suggestedDate })
    }

    func saveTravelPlan(context: ModelContext, profile: FamilyProfile?) {
        guard let country = selectedCountry else { return }

        let plan = TravelPlan(
            profile: profile,
            destination: country.countryName,
            countryCode: country.countryCode,
            departureDate: departureDate,
            requiredVaccines: country.required,
            recommendedVaccines: country.recommended
        )
        context.insert(plan)
        activeTravelPlan = plan
    }

    // MARK: - Helpers

    private func matchesVaccine(_ recordName: String, _ targetName: String) -> Bool {
        let r = recordName.lowercased()
        let t = targetName.lowercased()
        if r.contains(t) || t.contains(r) { return true }

        let allVaccines = cdcManager.allVaccines()
        if let vaccine = allVaccines.first(where: { $0.name.lowercased().contains(t) || t.contains($0.name.lowercased()) }) {
            return vaccine.alternateNames.contains(where: { r.contains($0.lowercased()) }) || r.contains(vaccine.name.lowercased())
        }
        return false
    }
}

// MARK: - Country Flag Helper

extension String {
    var countryFlag: String {
        let base: UInt32 = 127397
        return self.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }.map { String($0) }.joined()
    }
}
