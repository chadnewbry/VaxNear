import SwiftData
import SwiftUI

struct AddSideEffectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let record: VaccinationRecord

    @State private var symptom = ""
    @State private var customSymptom = ""
    @State private var severity: Severity = .mild
    @State private var onsetDate = Date.now
    @State private var durationDays = ""
    @State private var notes = ""

    private let commonSymptoms = [
        "Pain at injection site",
        "Swelling",
        "Redness",
        "Fatigue",
        "Headache",
        "Muscle pain",
        "Chills",
        "Fever",
        "Nausea",
        "Joint pain",
        "Dizziness",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Symptom") {
                    Picker("Symptom", selection: $symptom) {
                        Text("Select...").tag("")
                        ForEach(commonSymptoms, id: \.self) { Text($0).tag($0) }
                    }

                    if symptom == "Other" {
                        TextField("Describe symptom", text: $customSymptom)
                    }
                }

                Section("Details") {
                    Picker("Severity", selection: $severity) {
                        ForEach(Severity.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Onset Date", selection: $onsetDate, displayedComponents: .date)

                    TextField("Duration (days)", text: $durationDays)
                        .keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Side Effect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(effectiveSymptom.isEmpty)
                }
            }
        }
    }

    private var effectiveSymptom: String {
        symptom == "Other" ? customSymptom : symptom
    }

    private func save() {
        let effect = SideEffectLog(
            record: record,
            symptom: effectiveSymptom,
            severity: severity,
            onsetDate: onsetDate,
            durationDays: Int(durationDays),
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(effect)
        dismiss()
    }
}

#Preview {
    AddSideEffectView(record: VaccinationRecord(
        vaccineName: "COVID-19",
        dateAdministered: Date()
    ))
}
