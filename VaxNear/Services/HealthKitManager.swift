import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var isAvailable = HKHealthStore.isHealthDataAvailable()

    private let immunizationType = HKClinicalType(.immunizationRecord)

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [immunizationType]
        let writeTypes: Set<HKSampleType> = [immunizationType]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    // MARK: - Read Immunization Records

    /// Reads immunization records from HealthKit and returns lightweight value objects.
    func readImmunizationRecords() async -> [HealthKitVaccineRecord] {
        guard isAuthorized else { return [] }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: immunizationType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let clinicalRecords = samples as? [HKClinicalRecord], error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                let records = clinicalRecords.map { record in
                    HealthKitVaccineRecord(
                        vaccineName: record.displayName,
                        dateAdministered: record.startDate
                    )
                }
                continuation.resume(returning: records)
            }
            store.execute(query)
        }
    }

    // MARK: - Write Immunization Record

    func writeImmunizationRecord(from record: VaccinationRecord) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        let fhirData = buildFHIRImmunization(from: record)

        let clinicalRecord = try HKClinicalRecord(
            type: immunizationType,
            startDate: record.dateAdministered,
            endDate: record.dateAdministered,
            fhirResource: fhirData
        )

        try await store.save(clinicalRecord)
    }

    /// Syncs a record to HealthKit if authorized; fails silently.
    func syncIfAuthorized(record: VaccinationRecord) async {
        guard isAuthorized else { return }
        do {
            try await writeImmunizationRecord(from: record)
        } catch {
            print("HealthKit sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - FHIR Builder

    private func buildFHIRImmunization(from record: VaccinationRecord) -> HKFHIRResource {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: record.dateAdministered)

        var json: [String: Any] = [
            "resourceType": "Immunization",
            "status": "completed",
            "vaccineCode": ["text": record.vaccineName],
            "occurrenceDateTime": dateString,
            "lotNumber": record.lotNumber ?? ""
        ]

        if let manufacturer = record.manufacturer {
            json["manufacturer"] = ["display": manufacturer]
        }
        if let provider = record.administeringProvider {
            json["performer"] = [["actor": ["display": provider]]]
        }
        if let site = record.injectionSite {
            json["site"] = ["text": site]
        }

        let data = try! JSONSerialization.data(withJSONObject: json)

        return try! HKFHIRResource(
            type: .immunization,
            identifier: record.id.uuidString,
            data: data
        )
    }

    // MARK: - Errors

    enum HealthKitError: LocalizedError {
        case notAuthorized
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "HealthKit access not authorized."
            case .writeFailed: return "Failed to write record to HealthKit."
            }
        }
    }
}

/// Lightweight value type for records imported from HealthKit
struct HealthKitVaccineRecord: Identifiable {
    let id = UUID()
    let vaccineName: String
    let dateAdministered: Date
}
