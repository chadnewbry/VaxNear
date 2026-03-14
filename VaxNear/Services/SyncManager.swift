import CloudKit
import Combine
import Foundation
import SwiftUI

/// Monitors iCloud sync status via CloudKit account changes and persistent store remote change notifications.
@MainActor
final class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncedDate: Date?
    @Published var syncError: String?
    @Published var isCloudAvailable = false

    init() {
        checkCloudStatus()
        loadLastSynced()
        observeAccountChanges()
        observeRemoteChanges()
    }

    func checkCloudStatus() {
        CKContainer(identifier: "iCloud." + AppConfig.shared.bundleId).accountStatus { [weak self] status, error in
            Task { @MainActor in
                self?.isCloudAvailable = (status == .available)
                if let error {
                    self?.syncError = error.localizedDescription
                }
            }
        }
    }

    private func observeRemoteChanges() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lastSyncedDate = Date()
                self?.saveLastSynced()
                self?.isSyncing = false
            }
        }
    }

    private func observeAccountChanges() {
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkCloudStatus()
            }
        }
    }

    private func loadLastSynced() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date {
            lastSyncedDate = timestamp
        }
    }

    private func saveLastSynced() {
        UserDefaults.standard.set(lastSyncedDate, forKey: "lastCloudKitSyncDate")
    }
}
