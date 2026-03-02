import SwiftData
import SwiftUI

// MARK: - Milestone Definition

private struct AgeMilestone: Identifiable {
    let id: String
    let label: String
    let ageMonths: Int

    static let all: [AgeMilestone] = [
        .init(id: "birth", label: "Birth", ageMonths: 0),
        .init(id: "1m", label: "1 Month", ageMonths: 1),
        .init(id: "2m", label: "2 Months", ageMonths: 2),
        .init(id: "4m", label: "4 Months", ageMonths: 4),
        .init(id: "6m", label: "6 Months", ageMonths: 6),
        .init(id: "12m", label: "12 Months", ageMonths: 12),
        .init(id: "15m", label: "15 Months", ageMonths: 15),
        .init(id: "18m", label: "18 Months", ageMonths: 18),
        .init(id: "4y", label: "4–6 Years", ageMonths: 48),
        .init(id: "11y", label: "11–12 Years", ageMonths: 132),
        .init(id: "16y", label: "16 Years", ageMonths: 192),
    ]
}

struct ChildImmunizationScheduleView: View {
    let profile: FamilyProfile
    private let cdc = CDCDataManager.shared

    var body: some View {
        List {
            ForEach(AgeMilestone.all) { milestone in
                let vaccines = cdc.childSchedule(forAgeMonths: milestone.ageMonths)
                if !vaccines.isEmpty {
                    Section {
                        ForEach(vaccines, id: \.vaccineName) { vaccine in
                            let isRecorded = hasRecord(for: vaccine.vaccineName, dose: vaccine.doseNumber)
                            let isOverdue = !isRecorded && milestone.ageMonths < profile.ageInMonths

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vaccine.vaccineName)
                                        .font(.subheadline)
                                    if let dose = vaccine.doseNumber {
                                        Text("Dose \(dose)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if isRecorded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityLabel("Completed")
                                } else if isOverdue {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .accessibilityLabel("Overdue")
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Not yet due")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(milestone.label)
                            Spacer()
                            if milestone.ageMonths <= profile.ageInMonths {
                                Text("Reached")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(milestoneDate(for: milestone))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(profile.name)'s Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hasRecord(for vaccineName: String, dose: Int?) -> Bool {
        let nameLC = vaccineName.lowercased()
        let matchingRecords = profile.vaccinationRecords.filter {
            $0.vaccineName.lowercased().contains(nameLC) ||
            nameLC.contains($0.vaccineName.lowercased())
        }
        guard let dose else { return !matchingRecords.isEmpty }
        return matchingRecords.count >= dose
    }

    private func milestoneDate(for milestone: AgeMilestone) -> String {
        let date = Calendar.current.date(
            byAdding: .month,
            value: milestone.ageMonths,
            to: profile.dateOfBirth
        ) ?? profile.dateOfBirth
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChildImmunizationScheduleView(
            profile: FamilyProfile(
                name: "Baby",
                relationship: .child,
                dateOfBirth: Calendar.current.date(byAdding: .month, value: -4, to: .now)!
            )
        )
    }
}
