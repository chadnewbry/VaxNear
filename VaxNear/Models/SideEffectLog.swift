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
    @Attribute(.unique) var id: UUID
    var record: VaccinationRecord?
    var symptom: String
    var severity: Severity
    var onsetDate: Date
    var durationDays: Int?
    var notes: String?

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
        self.severity = severity
        self.onsetDate = onsetDate
        self.durationDays = durationDays
        self.notes = notes
    }
}
