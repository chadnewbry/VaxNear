import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftData
import SwiftUI

@MainActor
final class FinderViewModel: ObservableObject {

    // MARK: - Dependencies

    let locationManager = LocationManager()
    let finderService = VaccineSiteFinderService()
    private var cancellable: AnyCancellable?

    // MARK: - Published State

    @Published var selectedFilter: VaccineTypeFilter = .all
    @Published var selectedSite: VaccineSite?
    @Published var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var hasMovedMap = false
    @Published var visibleRegion: MKCoordinateRegion?
    @Published var sites: [VaccineSite] = []
    @Published var isSearching = false
    private(set) var hasPerformedInitialSearch = false

    // MARK: - Init

    init() {
        cancellable = finderService.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.sites = self.finderService.sites
                self.isSearching = self.finderService.isSearching
            }
        }
    }

    // MARK: - Search

    func initialSearch() async {
        guard !hasPerformedInitialSearch else { return }
        hasPerformedInitialSearch = true
        locationManager.requestPermission()
        // Wait briefly for location
        for _ in 0..<20 {
            if locationManager.currentLocation != nil { break }
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard let location = locationManager.currentLocation else {
            print("📍 Location not available after 5s wait")
            hasPerformedInitialSearch = false
            return
        }
        print("📍 Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        await search(at: location)
    }

    func searchThisArea() async {
        guard let region = visibleRegion else { return }
        let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        hasMovedMap = false
        await search(at: location)
    }

    func filterChanged() async {
        let location = locationManager.currentLocation
            ?? visibleRegion.map { CLLocation(latitude: $0.center.latitude, longitude: $0.center.longitude) }
        guard let location else { return }
        await search(at: location)
    }

    private func search(at location: CLLocation) async {
        await finderService.searchNearbySites(
            location: location,
            radiusMiles: 10,
            vaccineTypeFilter: selectedFilter
        )
    }

    // MARK: - Favorites

    func toggleFavorite(site: VaccineSite, context: ModelContext) {
        let name = site.name
        let address = site.address
        let descriptor = FetchDescriptor<SavedLocation>(
            predicate: #Predicate { $0.name == name && $0.address == address }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
        } else {
            let saved = SavedLocation(
                name: site.name,
                address: site.address,
                latitude: site.coordinate.latitude,
                longitude: site.coordinate.longitude,
                phoneNumber: site.phoneNumber,
                isWalkIn: site.isWalkIn,
                isFavorite: true
            )
            context.insert(saved)
        }
        try? context.save()
    }

    func isFavorite(site: VaccineSite, context: ModelContext) -> Bool {
        let name = site.name
        let address = site.address
        let descriptor = FetchDescriptor<SavedLocation>(
            predicate: #Predicate { $0.name == name && $0.address == address }
        )
        return (try? context.fetch(descriptor).first) != nil
    }

    // MARK: - Helpers

    func distanceText(for site: VaccineSite) -> String {
        guard let d = site.distance else { return "" }
        return String(format: "%.1f mi", d)
    }

    func pinTint(for category: VaccineSite.Category) -> Color {
        switch category {
        case .pharmacy: return .blue
        case .clinic: return .green
        case .hospital: return .red
        case .healthDept: return .purple
        }
    }
}
