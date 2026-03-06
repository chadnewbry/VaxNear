import SwiftData
import SwiftUI

struct TravelView: View {
    @StateObject private var vm = TravelViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]
    @Query(sort: \VaccinationRecord.dateAdministered) private var records: [VaccinationRecord]
    @Query(sort: \TravelPlan.departureDate, order: .reverse) private var travelPlans: [TravelPlan]

    var body: some View {
        NavigationStack {
            Group {
                if vm.selectedCountry != nil {
                    destinationReportView
                } else {
                    searchView
                }
            }
            .navigationTitle("Travel")
            .toolbar {
                if vm.selectedCountry != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation { vm.selectedCountry = nil; vm.searchText = "" }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Search")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.showingYellowCard = true
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .accessibilityLabel("Yellow Card")
                }
            }
            .sheet(isPresented: $vm.showingYellowCard) {
                YellowCardView()
            }
            .onAppear {
                vm.loadRecentDestinations(from: travelPlans)
            }
        }
    }

    // MARK: - Search View

    private var searchView: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Where are you traveling?", text: $vm.searchText)
                        .accessibilityLabel("Travel destination search")
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }

            if !vm.searchText.isEmpty {
                Section("Results") {
                    ForEach(vm.filteredCountries, id: \.countryCode) { country in
                        Button {
                            vm.selectCountry(country, records: records)
                        } label: {
                            HStack {
                                Text(country.countryCode.countryFlag)
                                    .font(.title2)
                                Text(country.countryName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if !country.required.isEmpty {
                                    Text("Required")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.red.opacity(0.15))
                                        .foregroundStyle(.red)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            } else if !vm.recentDestinations.isEmpty {
                Section("Recent Destinations") {
                    ForEach(vm.recentDestinations, id: \.countryCode) { country in
                        Button {
                            vm.selectCountry(country, records: records)
                        } label: {
                            HStack {
                                Text(country.countryCode.countryFlag)
                                    .font(.title2)
                                Text(country.countryName)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Planning a Trip?", systemImage: "airplane.departure")
                } description: {
                    Text("Enter your destination to see what vaccines you need.")
                }
            }

            Section {
                UpgradeBannerView(style: .prominent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
    }

    // MARK: - Destination Report

    private var destinationReportView: some View {
        List {
            if let country = vm.selectedCountry {
                // Header
                Section {
                    VStack(spacing: 8) {
                        Text(country.countryCode.countryFlag)
                            .font(.system(size: 64))
                        Text(country.countryName)
                            .font(.title.bold())
                        if country.malariaRisk {
                            Label("Malaria risk area", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if !country.notes.isEmpty {
                            Text(country.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                // Required Vaccines
                if !vm.requiredVaccineRows.isEmpty {
                    Section {
                        ForEach(vm.requiredVaccineRows) { row in
                            vaccineRow(row)
                        }
                    } header: {
                        Label("Required for Entry", systemImage: "exclamationmark.shield.fill")
                            .foregroundStyle(.red)
                    }
                }

                // Recommended Vaccines
                if !vm.recommendedVaccineRows.isEmpty {
                    Section {
                        ForEach(vm.recommendedVaccineRows) { row in
                            vaccineRow(row)
                        }
                    } header: {
                        Label("Recommended", systemImage: "hand.thumbsup.fill")
                    }
                }

                // Plan My Trip
                Section {
                    if vm.showingTimeline {
                        timelineView
                    } else {
                        VStack(spacing: 12) {
                            DatePicker("Departure Date", selection: $vm.departureDate, in: Date()..., displayedComponents: .date)
                            Button {
                                vm.generateTimeline()
                                vm.saveTravelPlan(context: modelContext, profile: profiles.first)
                            } label: {
                                Label("Plan My Trip", systemImage: "calendar.badge.clock")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("Generate a vaccination timeline for your trip")
                        }
                    }
                } header: {
                    Label("Travel Timeline", systemImage: "calendar")
                }
            }
        }
    }

    // MARK: - Vaccine Row

    private func vaccineRow(_ row: TravelVaccineRow) -> some View {
        HStack {
            Image(systemName: row.status.icon)
                .foregroundStyle(row.status.color)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.vaccineName)
                    .font(.body.weight(.medium))
                Text(row.status.label)
                    .font(.caption)
                    .foregroundStyle(row.status.color)
                if let date = row.lastDoseDate {
                    Text("Last dose: \(date, format: .dateTime.month(.abbreviated).day().year())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        ForEach(vm.timelineItems) { item in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.vaccineName)
                            .font(.body.weight(.medium))
                        Text(item.doseLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.suggestedDate, format: .dateTime.month(.abbreviated).day())
                            .font(.subheadline.weight(.semibold))
                        Text(item.weeksBeforeDeparture == 0 ? "Departure week" : "\(item.weeksBeforeDeparture)w before")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    NavigationLink {
                        FinderView(vm: FinderViewModel())
                    } label: {
                        Label("Find Site", systemImage: "mappin.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    NavigationLink {
                        AddRecordView()
                    } label: {
                        Label("Mark Done", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.green)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    TravelView()
        .modelContainer(for: [FamilyProfile.self, VaccinationRecord.self, TravelPlan.self], inMemory: true)
}
