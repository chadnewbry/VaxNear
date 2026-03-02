import SwiftUI

/// Share Profile Sheet — now delegates to the unified ExportView.
struct ShareProfileSheet: View {
    let profile: FamilyProfile

    var body: some View {
        ExportView(profile: profile)
    }
}

#Preview {
    ShareProfileSheet(profile: FamilyProfile(name: "Test", relationship: .selfUser, dateOfBirth: .now))
}
