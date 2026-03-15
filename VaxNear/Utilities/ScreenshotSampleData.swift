import Foundation
import SwiftData

#if DEBUG
enum ScreenshotSampleData {
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }

    @MainActor
    static func populate(context: ModelContext) {
        // Clear existing data
        try? context.delete(model: SideEffectLog.self)
        try? context.delete(model: VaccinationRecord.self)
        try? context.delete(model: TravelPlan.self)
        try? context.delete(model: FamilyProfile.self)
        try? context.delete(model: SavedLocation.self)
        try? context.delete(model: ScheduledReminder.self)

        // Mark onboarding complete and disable biometric lock
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "isBiometricLockEnabled")

        let cal = Calendar.current

        // MARK: - Family Profiles

        let selfProfile = FamilyProfile(
            name: "Alex Johnson",
            relationship: .selfUser,
            dateOfBirth: cal.date(from: DateComponents(year: 1990, month: 3, day: 15))!,
            colorTag: "#007AFF",
            allergies: "None",
            bloodType: .aPositive
        )
        context.insert(selfProfile)

        let spouse = FamilyProfile(
            name: "Jamie Johnson",
            relationship: .spouse,
            dateOfBirth: cal.date(from: DateComponents(year: 1992, month: 7, day: 22))!,
            colorTag: "#FF2D55",
            allergies: "Egg",
            bloodType: .oPositive
        )
        context.insert(spouse)

        let child = FamilyProfile(
            name: "Riley Johnson",
            relationship: .daughter,
            dateOfBirth: cal.date(from: DateComponents(year: 2021, month: 11, day: 8))!,
            colorTag: "#AF52DE"
        )
        context.insert(child)

        // MARK: - Vaccination Records

        let records: [(FamilyProfile, String, String?, Date, String?)] = [
            (selfProfile, "COVID-19 Booster", "Pfizer-BioNTech", cal.date(byAdding: .month, value: -2, to: Date())!, "CVS Pharmacy"),
            (selfProfile, "Influenza (Flu)", "Sanofi Pasteur", cal.date(byAdding: .month, value: -4, to: Date())!, "Walgreens"),
            (selfProfile, "Tdap", "GlaxoSmithKline", cal.date(byAdding: .year, value: -3, to: Date())!, "Dr. Smith's Office"),
            (spouse, "COVID-19 Booster", "Moderna", cal.date(byAdding: .month, value: -1, to: Date())!, "CVS Pharmacy"),
            (spouse, "Influenza (Flu)", "Sanofi Pasteur", cal.date(byAdding: .month, value: -3, to: Date())!, "Walgreens"),
            (child, "DTaP (Dose 4)", "Sanofi Pasteur", cal.date(byAdding: .month, value: -1, to: Date())!, "Pediatric Associates"),
            (child, "MMR (Dose 1)", "Merck", cal.date(byAdding: .month, value: -5, to: Date())!, "Pediatric Associates"),
            (child, "Hepatitis A", "Merck", cal.date(byAdding: .month, value: -6, to: Date())!, "Pediatric Associates"),
        ]

        for (profile, name, mfg, date, provider) in records {
            let record = VaccinationRecord(
                profile: profile,
                vaccineName: name,
                manufacturer: mfg,
                dateAdministered: date,
                administeringProvider: provider
            )
            context.insert(record)
        }

        // MARK: - Travel Plans

        let trip = TravelPlan(
            profile: selfProfile,
            destination: "Kenya",
            countryCode: "KE",
            departureDate: cal.date(byAdding: .month, value: 3, to: Date())!,
            requiredVaccines: ["Yellow Fever"],
            recommendedVaccines: ["Typhoid", "Hepatitis A", "Malaria Prophylaxis"],
            completedVaccines: ["Hepatitis A"]
        )
        context.insert(trip)

        let trip2 = TravelPlan(
            profile: spouse,
            destination: "Thailand",
            countryCode: "TH",
            departureDate: cal.date(byAdding: .month, value: 6, to: Date())!,
            requiredVaccines: [],
            recommendedVaccines: ["Hepatitis A", "Typhoid", "Japanese Encephalitis"],
            completedVaccines: []
        )
        context.insert(trip2)

        // MARK: - Saved Locations

        let locations: [(String, String, Double, Double, [String], Bool)] = [
            ("CVS Pharmacy", "123 Main St, San Francisco, CA 94102", 37.7749, -122.4194, ["COVID-19", "Flu", "Shingles", "Tdap"], true),
            ("Walgreens", "456 Market St, San Francisco, CA 94105", 37.7899, -122.4009, ["COVID-19", "Flu", "Pneumonia"], true),
            ("Kaiser Permanente", "2425 Geary Blvd, San Francisco, CA 94115", 37.7833, -122.4400, ["COVID-19", "Flu", "All Childhood Vaccines"], false),
            ("Pediatric Associates", "789 Oak Ave, San Francisco, CA 94117", 37.7694, -122.4484, ["All Childhood Vaccines", "Flu"], false),
        ]

        for (name, addr, lat, lon, vaccines, walkIn) in locations {
            let loc = SavedLocation(
                name: name,
                address: addr,
                latitude: lat,
                longitude: lon,
                vaccineTypesAvailable: vaccines,
                isWalkIn: walkIn,
                isFavorite: true
            )
            context.insert(loc)
        }

        try? context.save()
    }
}
#endif
