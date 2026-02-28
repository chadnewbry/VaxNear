import SwiftUI

struct FinderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("Find Vaccination Sites")
                    .font(.title2.bold())

                Text("Discover nearby pharmacies, clinics, and health departments offering vaccinations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .navigationTitle("Find")
        }
    }
}

#Preview {
    FinderView()
}
