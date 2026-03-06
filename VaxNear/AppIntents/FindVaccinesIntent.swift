import AppIntents

struct FindVaccinesIntent: AppIntent {
    static var title: LocalizedStringResource = "Find COVID Vaccines Near Me"
    static var description: IntentDescription = "Opens VaxNear to find COVID-19 vaccines nearby"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationState.shared.handle(.finder(vaccineFilter: "COVID-19"))
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Find COVID vaccines near me")
    }
}

struct ShowRecordsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Vaccine Records"
    static var description: IntentDescription = "Opens VaxNear to view your vaccination records"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationState.shared.handle(.records)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Show my vaccine records")
    }
}

