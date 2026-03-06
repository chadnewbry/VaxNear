import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var isAvailable = HKHealthStore.isHealthDataAvailable()
    @Published var lastSyncedDate: Date?
    @Published var isSyncing = false

    private let lastSyncKey = "HealthKitLastSyncDate"
    private let syncedRecordIDsKey = "HealthKitSyncedRecordIDs"

    private init() {
        lastSyncedDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    /// IDs of records already synced to HealthKit (avoids duplicates).
    private var syncedRecordIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: syncedRecordIDsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: syncedRecordIDsKey)
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        // Use a standard category type that doesn't require the restricted
        // health-records entitlement. We store vaccination metadata here.
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
            isAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
            isAuthorized = false
        }
    }

    // MARK: - Sync Vaccination Records

    /// Syncs a single vaccination record to HealthKit as a category sample with metadata.
    func syncRecord(_ record: VaccinationRecord) async throws {
        guard isAuthorized else { throw HealthKitError.notAuthorized }

        let recordID = record.id.uuidString
        guard !syncedRecordIDs.contains(recordID) else { return }

        guard let categoryType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        var metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: recordID,
            "VaccineName": record.vaccineName
        ]
        if let manufacturer = record.manufacturer { metadata["Manufacturer"] = manufacturer }
        if let lotNumber = record.lotNumber { metadata["LotNumber"] = lotNumber }
        if let provider = record.administeringProvider { metadata["Provider"] = provider }
        if let site = record.injectionSite { metadata["InjectionSite"] = site }

        let sample = HKCategorySample(
            type: categoryType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: record.dateAdministered,
            end: record.dateAdministered,
            metadata: metadata
        )

        try await store.save(sample)

        var ids = syncedRecordIDs
        ids.insert(recordID)
        syncedRecordIDs = ids
    }

    /// Syncs all provided vaccination records to HealthKit.
    func syncAllRecords(_ records: [VaccinationRecord]) async {
        guard isAuthorized else { return }

        isSyncing = true
        defer {
            isSyncing = false
            lastSyncedDate = Date()
            UserDefaults.standard.set(lastSyncedDate, forKey: lastSyncKey)
        }

        for record in records {
            do {
                try await syncRecord(record)
            } catch {
                print("HealthKit sync failed for \(record.vaccineName): \(error.localizedDescription)")
            }
        }
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
