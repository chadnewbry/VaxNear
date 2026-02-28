import SwiftUI

struct TravelView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "airplane")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("Travel Vaccine Planner")
                    .font(.title2.bold())

                Text("Plan ahead with destination-specific vaccine recommendations powered by CDC data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .navigationTitle("Travel")
        }
    }
}

#Preview {
    TravelView()
}
