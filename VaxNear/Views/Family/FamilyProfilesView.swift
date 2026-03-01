import SwiftData
import SwiftUI

struct FamilyProfilesView: View {
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddProfile = false
    @State private var profileToDelete: FamilyProfile?

    var body: some View {
        List {
            ForEach(profiles) { profile in
                NavigationLink {
                    ProfileDetailView(profile: profile)
                } label: {
                    ProfileRow(profile: profile)
                }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    profileToDelete = profiles[index]
                }
            }
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Family Profiles", systemImage: "person.3")
                } description: {
                    Text("Add profiles for yourself and your family to track vaccination records.")
                } actions: {
                    Button("Add Profile") { showingAddProfile = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Family")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddProfile = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProfile) {
            AddEditProfileView()
        }
        .alert("Delete Profile?", isPresented: .init(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    modelContext.delete(profile)
                    profileToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            if let profile = profileToDelete {
                Text("This will permanently delete \(profile.name)'s profile and all associated records.")
            }
        }
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: FamilyProfile

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: profile.colorTag))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    Text(profile.relationship.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }

                Text("\(profile.vaccinationRecords.count) record\(profile.vaccinationRecords.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        FamilyProfilesView()
    }
    .modelContainer(for: FamilyProfile.self, inMemory: true)
}
