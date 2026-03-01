import SwiftUI

struct ShareProfileSheet: View {
    let profile: FamilyProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Share \(profile.name)'s Records")
                    .font(.title3.bold())

                Text("Generate a read-only summary of vaccination records to share with family members or healthcare providers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                ShareLink(item: exportText) {
                    Label("Share as Text", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var exportText: String {
        var lines = [
            "Vaccination Records — \(profile.name)",
            "Relationship: \(profile.relationship.displayName)",
            "Date of Birth: \(formatted(profile.dateOfBirth))",
            "",
            "Records:"
        ]

        let sorted = profile.vaccinationRecords.sorted { $0.dateAdministered < $1.dateAdministered }
        if sorted.isEmpty {
            lines.append("  No records on file.")
        } else {
            for record in sorted {
                var line = "  • \(record.vaccineName) — \(formatted(record.dateAdministered))"
                if let mfg = record.manufacturer, !mfg.isEmpty {
                    line += " (\(mfg))"
                }
                lines.append(line)
            }
        }

        lines.append("")
        lines.append("Exported from VaxNear on \(formatted(Date.now))")
        return lines.joined(separator: "\n")
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }
}

#Preview {
    ShareProfileSheet(profile: FamilyProfile(name: "Test", relationship: .selfUser, dateOfBirth: .now))
}
