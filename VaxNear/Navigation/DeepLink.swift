import Foundation

enum DeepLink {
    case finder(vaccineFilter: String? = nil)
    case records
    case travel(country: String? = nil)
    case family
    case recordDetail(id: UUID)

    static func from(url: URL) -> DeepLink? {
        guard url.scheme == "vaxnear" else { return nil }
        switch url.host {
        case "finder":
            let filter = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "vaccine" })?.value
            return .finder(vaccineFilter: filter)
        case "records":
            return .records
        case "travel":
            let country = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "country" })?.value
            return .travel(country: country)
        case "family":
            return .family
        case "record":
            if let idStr = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
               let id = UUID(uuidString: idStr) {
                return .recordDetail(id: id)
            }
            return .records
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .finder(let filter):
            var components = URLComponents(string: "vaxnear://finder")!
            if let filter { components.queryItems = [URLQueryItem(name: "vaccine", value: filter)] }
            return components.url!
        case .records:
            return URL(string: "vaxnear://records")!
        case .travel(let country):
            var components = URLComponents(string: "vaxnear://travel")!
            if let country { components.queryItems = [URLQueryItem(name: "country", value: country)] }
            return components.url!
        case .family:
            return URL(string: "vaxnear://family")!
        case .recordDetail(let id):
            var components = URLComponents(string: "vaxnear://record")!
            components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
            return components.url!
        }
    }
}
