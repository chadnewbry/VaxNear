import SwiftUI

enum AppTab: Int, Hashable {
    case finder = 0
    case records = 1
    case family = 2
    case travel = 3
    case settings = 4
}

@MainActor
final class NavigationState: ObservableObject {
    static let shared = NavigationState()

    @Published var selectedTab: AppTab = .finder
    @Published var vaccineFilter: String?
    @Published var travelCountry: String?
    @Published var profileFilter: UUID?

    func showRecords(for profileID: UUID) {
        profileFilter = profileID
        selectedTab = .records
    }

    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .finder(let filter):
            vaccineFilter = filter
            selectedTab = .finder
        case .records:
            selectedTab = .records
        case .family:
            selectedTab = .family
        case .travel(let country):
            travelCountry = country
            selectedTab = .travel
        case .recordDetail:
            selectedTab = .records
        }
    }
}
