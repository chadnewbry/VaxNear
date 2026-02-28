import SwiftUI

struct RecordsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("Vaccination Records")
                    .font(.title2.bold())

                Text("Keep a complete timeline of your immunization history, synced with HealthKit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .navigationTitle("Records")
        }
    }
}

#Preview {
    RecordsView()
}
