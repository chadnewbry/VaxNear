import AppIntents

struct VaxNearShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindVaccinesIntent(),
            phrases: [
                "Find COVID vaccines near me in \(.applicationName)",
                "Find vaccines in \(.applicationName)"
            ],
            shortTitle: "Find COVID Vaccines",
            systemImageName: "cross.vial"
        )
        AppShortcut(
            intent: ShowRecordsIntent(),
            phrases: [
                "Show my vaccine records in \(.applicationName)",
                "Open my vaccination records in \(.applicationName)"
            ],
            shortTitle: "Vaccine Records",
            systemImageName: "list.clipboard"
        )
        AppShortcut(
            intent: TravelVaccinesIntent(),
            phrases: [
                "What vaccines do I need in \(.applicationName)",
                "Travel vaccines in \(.applicationName)"
            ],
            shortTitle: "Travel Vaccines",
            systemImageName: "airplane"
        )
    }
}
