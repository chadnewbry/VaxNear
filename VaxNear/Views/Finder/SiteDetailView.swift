import MapKit
import SwiftData
import SwiftUI

struct SiteDetailView: View {
    let site: VaccineSite
    @ObservedObject var viewModel: FinderViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isFav = false
    @State private var travelTime: String?
    @State private var showAddRecord = false

    var body: some View {
        List {
            // MARK: - Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: site.category.systemImage)
                            .foregroundStyle(viewModel.pinTint(for: site.category))
                            .font(.title2)
                        Text(site.category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let d = site.distance {
                            Text(String(format: "%.1f mi", d))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(site.name)
                        .font(.title2.bold())
                    Text(site.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let hours = site.operatingHours {
                        Label(hours, systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let travel = travelTime {
                        Label(travel, systemImage: "car.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Contact
            if let phone = site.phoneNumber {
                Section {
                    Link(destination: URL(string: "tel:\(phone.filter { $0.isNumber })")!) {
                        Label(phone, systemImage: "phone.fill")
                    }
                }
            }

            // MARK: - Actions
            Section {
                if let url = site.appointmentURL {
                    Link(destination: url) {
                        Label("Book Appointment", systemImage: "calendar.badge.plus")
                    }
                }

                Button {
                    openDirections()
                } label: {
                    Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }

                Button {
                    isFav.toggle()
                    viewModel.toggleFavorite(site: site, context: modelContext)
                } label: {
                    Label(
                        isFav ? "Remove from Favorites" : "Save to Favorites",
                        systemImage: isFav ? "heart.fill" : "heart"
                    )
                }
                .tint(isFav ? .red : .accentColor)

                Button {
                    showAddRecord = true
                } label: {
                    Label("I Got Vaccinated Here", systemImage: "checkmark.seal.fill")
                }
            }

            // MARK: - Map Preview
            Section {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: site.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(site.name, coordinate: site.coordinate)
                        .tint(viewModel.pinTint(for: site.category))
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .allowsHitTesting(false)
            }
        }
        .navigationTitle(site.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddRecord) {
            NavigationStack {
                AddRecordView()
            }
        }
        .onAppear {
            isFav = viewModel.isFavorite(site: site, context: modelContext)
            estimateTravelTime()
        }
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: site.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = site.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func estimateTravelTime() {
        guard let userLoc = viewModel.locationManager.currentLocation else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: site.coordinate))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculateETA { response, _ in
            guard let eta = response else { return }
            let driveMin = Int(eta.expectedTravelTime / 60)
            Task { @MainActor in
                travelTime = "\(driveMin) min drive"
            }
        }
    }
}
