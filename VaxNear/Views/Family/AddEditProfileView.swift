import SwiftData
import SwiftUI

struct AddEditProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationManager: NotificationManager

    var existingProfile: FamilyProfile?

    @State private var name: String = ""
    @State private var relationship: Relationship = .selfUser
    @State private var dateOfBirth: Date = Date()
    @State private var selectedColor: String = ProfileColors.presets[0]

    private var isEditing: Bool { existingProfile != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)

                    Picker("Relationship", selection: $relationship) {
                        ForEach(Relationship.allCases) { rel in
                            Text(rel.displayName).tag(rel)
                        }
                    }

                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                }

                Section("Color Tag") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(ProfileColors.presets, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { selectedColor = color }
                                .accessibilityLabel("Color \(ProfileColors.presets.firstIndex(of: color).map { String($0 + 1) } ?? "")")
                                .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
                                .accessibilityHint("Double tap to select this color")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityHint(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Enter a name first" : "Save this profile")
                }
            }
            .onAppear {
                if let profile = existingProfile {
                    name = profile.name
                    relationship = profile.relationship
                    dateOfBirth = profile.dateOfBirth
                    selectedColor = profile.colorTag
                }
            }
        }
    }

    private func save() {
        if let profile = existingProfile {
            profile.name = name.trimmingCharacters(in: .whitespaces)
            profile.relationship = relationship
            profile.dateOfBirth = dateOfBirth
            profile.colorTag = selectedColor
        } else {
            let profile = FamilyProfile(
                name: name.trimmingCharacters(in: .whitespaces),
                relationship: relationship,
                dateOfBirth: dateOfBirth,
                colorTag: selectedColor
            )
            modelContext.insert(profile)

            if relationship == .child {
                notificationManager.scheduleChildMilestoneReminders(for: profile)
            }
        }
        dismiss()
    }
}

#Preview {
    AddEditProfileView()
        .modelContainer(for: FamilyProfile.self, inMemory: true)
        .environmentObject(NotificationManager())
}
