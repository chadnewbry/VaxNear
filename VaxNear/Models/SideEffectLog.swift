import Foundation
import SwiftData

enum Severity: String, Codable, CaseIterable, Identifiable {
    case mild
    case moderate
    case severe

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

@Model
final class SideEffectLog {
    var id: UUID = UUID()
    var record: VaccinationRecord?
    var symptom: String = ""
    var severityRawValue: String = Severity.mild.rawValue
    var onsetDate: Date = Date()
    var durationDays: Int?
    var notes: String?

    @Transient var severity: Severity {
        get { Severity(rawValue: severityRawValue) ?? .mild }
        set { severityRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        record: VaccinationRecord? = nil,
        symptom: String,
        severity: Severity,
        onsetDate: Date,
        durationDays: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.record = record
        self.symptom = symptom
        self.severityRawValue = severity.rawValue
        self.onsetDate = onsetDate
        self.durationDays = durationDays
        self.notes = notes
    }
}
