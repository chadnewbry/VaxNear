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
    @State private var allergies: String = ""
    @State private var bloodType: BloodType = .unknown
    @State private var medicalNotes: String = ""
    @State private var emergencyContact: String = ""
    @State private var insuranceInfo: String = ""

    private var isEditing: Bool { existingProfile != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)

                    Picker("Relationship", selection: $relationship) {
                        ForEach(Relationship.allCases) { rel in
                            Label(rel.displayName, systemImage: rel.systemImage).tag(rel)
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
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Medical Information") {
                    Picker("Blood Type", selection: $bloodType) {
                        ForEach(BloodType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Allergies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Penicillin, Eggs, Latex", text: $allergies, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    VStack(alignment: .leading) {
                        Text("Medical Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Asthma, immunocompromised", text: $medicalNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }

                Section("Additional Info") {
                    VStack(alignment: .leading) {
                        Text("Emergency Contact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Name and phone number", text: $emergencyContact)
                    }

                    VStack(alignment: .leading) {
                        Text("Insurance Info")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Provider, policy number", text: $insuranceInfo)
                    }
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
                }
            }
            .onAppear {
                if let profile = existingProfile {
                    name = profile.name
                    relationship = profile.relationship
                    dateOfBirth = profile.dateOfBirth
                    selectedColor = profile.colorTag
                    allergies = profile.allergies
                    bloodType = profile.bloodType
                    medicalNotes = profile.medicalNotes
                    emergencyContact = profile.emergencyContact
                    insuranceInfo = profile.insuranceInfo
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
            profile.allergies = allergies.trimmingCharacters(in: .whitespaces)
            profile.bloodType = bloodType
            profile.medicalNotes = medicalNotes.trimmingCharacters(in: .whitespaces)
            profile.emergencyContact = emergencyContact.trimmingCharacters(in: .whitespaces)
            profile.insuranceInfo = insuranceInfo.trimmingCharacters(in: .whitespaces)
        } else {
            let profile = FamilyProfile(
                name: name.trimmingCharacters(in: .whitespaces),
                relationship: relationship,
                dateOfBirth: dateOfBirth,
                colorTag: selectedColor,
                allergies: allergies.trimmingCharacters(in: .whitespaces),
                bloodType: bloodType,
                medicalNotes: medicalNotes.trimmingCharacters(in: .whitespaces),
                emergencyContact: emergencyContact.trimmingCharacters(in: .whitespaces),
                insuranceInfo: insuranceInfo.trimmingCharacters(in: .whitespaces)
            )
            modelContext.insert(profile)

            if relationship.isChild {
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
