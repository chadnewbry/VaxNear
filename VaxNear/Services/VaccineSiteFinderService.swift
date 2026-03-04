import CoreLocation
import Foundation
import MapKit

@MainActor
final class VaccineSiteFinderService: ObservableObject {

    // MARK: - Published

    @Published var sites: [VaccineSite] = []
    @Published var isSearching = false
    @Published var searchError: String?

    // MARK: - Cache

    private struct CacheKey: Hashable {
        let lat: Double
        let lon: Double
        let radiusMiles: Double
        let filter: String
    }

    private var cache: [CacheKey: CacheEntry] = [:]

    private struct CacheEntry {
        let sites: [VaccineSite]
        let timestamp: Date
    }

    private let cacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Debounce

    private var searchTask: Task<Void, Never>?

    // MARK: - Public API

    func searchNearbySites(
        location: CLLocation,
        radiusMiles: Double = 10,
        vaccineTypeFilter: VaccineTypeFilter = .all
    ) async {
        // Cancel any in-flight search
        searchTask?.cancel()

        let key = CacheKey(
            lat: round(location.coordinate.latitude * 100) / 100,
            lon: round(location.coordinate.longitude * 100) / 100,
            radiusMiles: radiusMiles,
            filter: vaccineTypeFilter.rawValue
        )

        // Check cache (with TTL)
        if let entry = cache[key],
           Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            sites = entry.sites
            return
        }

        isSearching = true
        searchError = nil

        let task = Task {
            var allSites: [String: VaccineSite] = [:]
            var errorCount = 0
            let queries = vaccineTypeFilter.searchQueries

            // Run all queries concurrently
            await withTaskGroup(of: Result<[VaccineSite], Error>.self) { group in
                for query in queries {
                    group.addTask {
                        do {
                            let results = try await self.performSearch(
                                query: query,
                                location: location,
                                radiusMiles: radiusMiles
                            )
                            return .success(results)
                        } catch {
                            return .failure(error)
                        }
                    }
                }

                for await result in group {
                    if Task.isCancelled { return }
                    switch result {
                    case .success(let results):
                        for site in results {
                            allSites[site.id] = site
                        }
                    case .failure:
                        errorCount += 1
                    }
                }
            }

            if Task.isCancelled { return }

            let sorted = allSites.values.sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
            cache[key] = CacheEntry(sites: sorted, timestamp: Date())
            sites = sorted
            isSearching = false

            if sorted.isEmpty && errorCount == queries.count {
                searchError = "Unable to search for sites. Check your connection and try again."
            } else if sorted.isEmpty && errorCount > 0 {
                searchError = "Some searches failed. Results may be incomplete."
            }
        }

        searchTask = task
        await task.value
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func performSearch(
        query: String,
        location: CLLocation,
        radiusMiles: Double
    ) async throws -> [VaccineSite] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radiusMiles * 1609.344 * 2,
            longitudinalMeters: radiusMiles * 1609.344 * 2
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.compactMap { item -> VaccineSite? in
            guard let name = item.name else { return nil }

            let coordinate = item.placemark.coordinate
            let distanceMeters = location.distance(
                from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            let distanceMiles = distanceMeters / 1609.344

            let category = Self.categorize(item: item, query: query)
            let appointmentURL = Self.appointmentURL(for: name)

            let address = Self.formatAddress(item.placemark)

            return VaccineSite(
                id: "\(coordinate.latitude),\(coordinate.longitude)-\(name)",
                name: name,
                address: address,
                coordinate: coordinate,
                distance: distanceMiles,
                phoneNumber: item.phoneNumber,
                category: category,
                appointmentURL: appointmentURL
            )
        }
    }

    // MARK: - Categorization

    private static func categorize(item: MKMapItem, query: String) -> VaccineSite.Category {
        let name = (item.name ?? "").lowercased()
        let cats = item.pointOfInterestCategory

        if cats == .hospital {
            return .hospital
        }

        let pharmacyKeywords = ["pharmacy", "cvs", "walgreens", "walmart", "rite aid", "costco", "sam's club", "kroger", "publix"]
        if pharmacyKeywords.contains(where: { name.contains($0) }) || cats == .pharmacy {
            return .pharmacy
        }

        let healthDeptKeywords = ["health department", "public health", "county health"]
        if healthDeptKeywords.contains(where: { name.contains($0) }) {
            return .healthDept
        }

        if query.contains("hospital") { return .hospital }
        if query.contains("health department") { return .healthDept }
        if query.contains("pharmacy") { return .pharmacy }

        return .clinic
    }

    // MARK: - Appointment Deep Links

    private static let appointmentLinks: [(keyword: String, url: String)] = [
        ("cvs", "https://www.cvs.com/immunizations/covid-19-vaccine"),
        ("walgreens", "https://www.walgreens.com/findcare/vaccination/covid/19/landing"),
        ("walmart", "https://www.walmart.com/pharmacy/clinical-services/immunization"),
    ]

    private static func appointmentURL(for name: String) -> URL? {
        let lower = name.lowercased()
        for link in appointmentLinks {
            if lower.contains(link.keyword) {
                return URL(string: link.url)
            }
        }
        return nil
    }

    // MARK: - Address Formatting

    private static func formatAddress(_ placemark: MKPlacemark) -> String {
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
        ].compactMap { $0 }
        return components.joined(separator: " ")
    }
}
