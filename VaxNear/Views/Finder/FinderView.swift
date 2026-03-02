import MapKit
import SwiftData
import SwiftUI

struct FinderView: View {
    @StateObject private var vm = FinderViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var sheetDetent: PresentationDetent = .fraction(0.4)
    @State private var showFavorites = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                if vm.hasMovedMap {
                    searchAreaButton
                }
            }
            .sheet(isPresented: .constant(true)) {
                siteListSheet
                    .presentationDetents([.fraction(0.4), .large], selection: $sheetDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.4)))
                    .interactiveDismissDisabled()
            }
            .navigationTitle("Find")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFavorites = true
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel("Favorites")
                }
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesView()
            }
            .task {
                ShortcutDonation.donateVaccineSearch(vaccine: "")
                await vm.initialSearch()
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $vm.mapPosition) {
            UserAnnotation()
            ForEach(vm.sites) { site in
                Annotation(site.name, coordinate: site.coordinate) {
                    Button {
                        vm.selectedSite = site
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "syringe.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(vm.pinTint(for: site.category))
                                .clipShape(Circle())
                        }
                    }
                    .accessibilityLabel("\(site.name) vaccination site")
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            vm.visibleRegion = context.region
            vm.hasMovedMap = true
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Search Area Button

    private var searchAreaButton: some View {
        Button {
            Task { await vm.searchThisArea() }
        } label: {
            Label("Search this area", systemImage: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("Search this area for vaccination sites")
        .padding(.top, 60)
    }

    // MARK: - Site List Sheet

    private var siteListSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.vertical, 8)
                Divider()
                siteList
            }
            .navigationTitle("Nearby Sites")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VaccineTypeFilter.allCases) { filter in
                    Button {
                        vm.selectedFilter = filter
                        Task { await vm.filterChanged() }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                vm.selectedFilter == filter
                                    ? Color.accentColor
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(vm.selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(filter.rawValue) filter")
                    .accessibilityAddTraits(vm.selectedFilter == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Site List

    @ViewBuilder
    private var siteList: some View {
        if !vm.locationManager.isAuthorized && vm.locationManager.isDenied {
            noPermissionView
        } else if vm.isSearching {
            loadingView
        } else if vm.sites.isEmpty {
            emptyView
        } else {
            List(vm.sites) { site in
                NavigationLink {
                    SiteDetailView(site: site, viewModel: vm)
                } label: {
                    siteRow(site)
                }
            }
            .listStyle(.plain)
        }
    }

    private func siteRow(_ site: VaccineSite) -> some View {
        HStack(spacing: 12) {
            Image(systemName: site.category.systemImage)
                .foregroundStyle(vm.pinTint(for: site.category))
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(site.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.distanceText(for: site))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if site.isWalkIn {
                    Text("Walk-in")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(site.name), \(site.address), \(vm.distanceText(for: site))\(site.isWalkIn ? ", walk-in available" : "")")
    }

    // MARK: - Empty / Error States

    private var noPermissionView: some View {
        ContentUnavailableView {
            Label("Location Access Required", systemImage: "location.slash")
        } description: {
            Text("VaxNear needs your location to find nearby vaccination sites.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens device settings to enable location access")
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Sites Found", systemImage: "mappin.slash")
        } description: {
            Text("No vaccination sites found nearby. Try expanding your search radius in Settings.")
        }
    }

    private var loadingView: some View {
        List(0..<5, id: \.self) { _ in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 10)
                }
            }
            .redacted(reason: .placeholder)
        }
        .listStyle(.plain)
    }
}

#Preview {
    FinderView()
        .modelContainer(for: SavedLocation.self, inMemory: true)
}
