import AppIntents

enum ShortcutDonation {
    static func donateVaccineSearch(vaccine: String) {
        let intent = FindVaccinesIntent()
        Task {
            try? await intent.donate()
        }
    }

    static func donateRecordsView() {
        let intent = ShowRecordsIntent()
        Task {
            try? await intent.donate()
        }
    }

}
