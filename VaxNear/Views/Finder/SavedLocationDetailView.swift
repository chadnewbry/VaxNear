import MapKit
import SwiftData
import SwiftUI

struct SavedLocationDetailView: View {
    @Bindable var location: SavedLocation
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var travelTime: String?
    @State private var showDeleteConfirmation = false

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    var body: some View {
        List {
            // MARK: - Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(location.name)
                        .font(.title2.bold())
                    Text(location.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if location.isWalkIn {
                        Label("Walk-ins Welcome", systemImage: "figure.walk")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    if let travel = travelTime {
                        Label(travel, systemImage: "car.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Vaccines Available
            if !location.vaccineTypesAvailable.isEmpty {
                Section("Available Vaccines") {
                    ForEach(location.vaccineTypesAvailable, id: \.self) { vaccine in
                        Label(vaccine, systemImage: "syringe.fill")
                    }
                }
            }

            // MARK: - Contact & Actions
            Section {
                if let phone = location.phoneNumber {
                    Link(destination: URL(string: "tel:\(phone.filter { $0.isNumber })")!) {
                        Label(phone, systemImage: "phone.fill")
                    }
                }

                Button {
                    openDirections()
                } label: {
                    Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }

                ShareLink(
                    item: "\(location.name)\n\(location.address)",
                    subject: Text(location.name),
                    message: Text("Check out this vaccination site")
                ) {
                    Label("Share Location", systemImage: "square.and.arrow.up")
                }
            }

            // MARK: - Map Preview
            Section {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(location.name, coordinate: coordinate)
                        .tint(.red)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .allowsHitTesting(false)
                .accessibilityLabel("Map showing location of \(location.name)")
            }

            // MARK: - Remove
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove from Favorites", systemImage: "heart.slash")
                }
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove \(location.name) from favorites?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                location.isFavorite = false
                try? modelContext.save()
                dismiss()
            }
        }
        .onAppear {
            estimateTravelTime()
        }
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func estimateTravelTime() {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.transportType = .automobile

        MKDirections(request: request).calculateETA { response, _ in
            guard let eta = response else { return }
            let driveMin = Int(eta.expectedTravelTime / 60)
            Task { @MainActor in
                travelTime = "\(driveMin) min drive"
            }
        }
    }
}

#Preview {
    NavigationStack {
        SavedLocationDetailView(location: SavedLocation(
            name: "CVS Pharmacy",
            address: "123 Main St, Springfield, IL",
            latitude: 39.7817,
            longitude: -89.6501,
            phoneNumber: "(217) 555-0123",
            vaccineTypesAvailable: ["COVID-19", "Flu", "Shingles"],
            isWalkIn: true,
            isFavorite: true
        ))
    }
    .modelContainer(for: SavedLocation.self, inMemory: true)
}
