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

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    // MARK: - Read Immunization Records

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

    // MARK: - Sync (Read-Only for v1)

    /// HealthKit clinical records are read-only. This is a no-op placeholder
    /// for future server-signed FHIR write support.
    func syncIfAuthorized(record: VaccinationRecord) async {
        // Clinical records cannot be written directly via HealthKit.
        // A future version could use a SMART on FHIR server to push records.
    }

    // MARK: - Errors

    enum HealthKitError: LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "HealthKit access not authorized."
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
