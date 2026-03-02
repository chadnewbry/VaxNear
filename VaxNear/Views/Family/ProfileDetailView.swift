import SwiftData
import SwiftUI

struct ProfileDetailView: View {
    @Bindable var profile: FamilyProfile
    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var showingShareSheet = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color(hex: profile.colorTag))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.title3.bold())
                        HStack(spacing: 8) {
                            Text(profile.relationship.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.fill.tertiary)
                                .clipShape(Capsule())
                            Text(ageString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Vaccination Records (\(profile.vaccinationRecords.count))") {
                if profile.vaccinationRecords.isEmpty {
                    Text("No records yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profile.vaccinationRecords.sorted { $0.dateAdministered > $1.dateAdministered }) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.vaccineName)
                                .font(.subheadline.bold())
                            Text(record.dateAdministered, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if profile.relationship == .child {
                Section {
                    NavigationLink {
                        ChildImmunizationScheduleView(profile: profile)
                    } label: {
                        Label("Immunization Schedule", systemImage: "calendar.badge.checkmark")
                    }
                }
            }

            Section {
                Button {
                    showingShareSheet = true
                } label: {
                    Label("Share Profile", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share profile")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditProfileView(existingProfile: profile)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareProfileSheet(profile: profile)
        }
    }

    private var ageString: String {
        let years = profile.ageInYears
        let months = profile.ageInMonths
        if years < 2 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        }
        return "\(years) year\(years == 1 ? "" : "s") old"
    }
}

#Preview {
    NavigationStack {
        ProfileDetailView(profile: FamilyProfile(name: "Test", relationship: .child, dateOfBirth: Calendar.current.date(byAdding: .month, value: -6, to: .now)!))
    }
    .modelContainer(for: FamilyProfile.self, inMemory: true)
}
