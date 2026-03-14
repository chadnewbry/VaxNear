import Foundation

/// Single source of truth for app configuration.
/// Reads from `app-config.json` bundled in `.asc/` at the project root.
struct AppConfig: Codable {
    let bundleId: String
    let appName: String?
    let copyright: String
    let urls: URLs
    let review: Review?

    struct URLs: Codable {
        let website: String
        let privacyPolicy: String
        let termsOfService: String
        let support: String
    }

    struct Review: Codable {
        let demoAccountRequired: Bool?
        let contactFirstName: String?
        let contactLastName: String?
        let contactEmail: String?
        let contactPhone: String?
    }

    /// Shared singleton loaded from the app bundle.
    static let shared: AppConfig = {
        let configName: String
        if Bundle.main.url(forResource: "app-config", withExtension: "json") != nil {
            configName = "app-config"
        } else {
            fatalError("Missing app-config.json in bundle. Add .asc/app-config.json to 'Copy Bundle Resources'.")
        }

        guard let url = Bundle.main.url(forResource: configName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Failed to load \(configName).json from bundle.")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            fatalError("Failed to decode \(configName).json: \(error)")
        }
    }()
}
