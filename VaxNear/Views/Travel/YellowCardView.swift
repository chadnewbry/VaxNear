import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct YellowCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]
    @Query(sort: \VaccinationRecord.dateAdministered) private var records: [VaccinationRecord]
    @State private var selectedProfileID: UUID?
    @State private var showingExportView = false

    private var selectedProfile: FamilyProfile? {
        if let id = selectedProfileID { return profiles.first(where: { $0.id == id }) }
        return profiles.first
    }

    private var profileRecords: [VaccinationRecord] {
        guard let profile = selectedProfile else { return records }
        return records.filter { $0.profile?.id == profile.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Yellow Card Header
                    VStack(spacing: 4) {
                        Text("INTERNATIONAL CERTIFICATE OF VACCINATION")
                            .font(.caption.weight(.bold))
                            .tracking(1)
                        Text("OR PROPHYLAXIS")
                            .font(.caption2.weight(.semibold))
                            .tracking(0.5)
                        Rectangle()
                            .frame(height: 2)
                            .padding(.horizontal, 40)
                            .padding(.top, 4)
                        if let profile = selectedProfile {
                            Text(profile.name.uppercased())
                                .font(.title3.weight(.bold))
                                .padding(.top, 8)
                            Text("Date of Birth: \(profile.dateOfBirth, format: .dateTime.month(.wide).day().year())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.25))

                    // Profile picker
                    if profiles.count > 1 {
                        Picker("Profile", selection: $selectedProfileID) {
                            ForEach(profiles) { profile in
                                Text(profile.name).tag(profile.id as UUID?)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                    }

                    // Vaccination Table
                    VStack(spacing: 0) {
                        // Table header
                        HStack {
                            Text("Vaccine").font(.caption2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Date").font(.caption2.bold()).frame(width: 80)
                            Text("Provider").font(.caption2.bold()).frame(width: 80)
                            Text("Lot #").font(.caption2.bold()).frame(width: 60)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))

                        if profileRecords.isEmpty {
                            ContentUnavailableView {
                                Label("No Records", systemImage: "doc.text")
                            } description: {
                                Text("Add vaccination records to populate your Yellow Card.")
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(profileRecords) { record in
                                HStack {
                                    Text(record.vaccineName)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(record.dateAdministered, format: .dateTime.month(.twoDigits).day(.twoDigits).year(.twoDigits))
                                        .font(.caption2)
                                        .frame(width: 80)
                                    Text(record.administeringProvider ?? "—")
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: 80)
                                    Text(record.lotNumber ?? "—")
                                        .font(.caption2)
                                        .frame(width: 60)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                Divider().padding(.horizontal)
                            }
                        }
                    }

                    // QR Code (if SMART Health Card data available)
                    let smartRecords = profileRecords.filter { $0.smartHealthCardData != nil }
                    if !smartRecords.isEmpty {
                        VStack(spacing: 8) {
                            Text("SMART Health Card")
                                .font(.caption.weight(.semibold))
                            if let data = smartRecords.first?.smartHealthCardData,
                               let qrImage = generateQRCode(from: data) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                                    .accessibilityLabel("SMART Health Card QR code")
                            }
                            Text("Scan for digital verification")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Yellow Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingExportView = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export records")
                }
            }
            .sheet(isPresented: $showingExportView) {
                if let profile = selectedProfile {
                    ExportView(profile: profile)
                }
            }
            .onAppear {
                selectedProfileID = profiles.first?.id
            }
        }
    }

    // MARK: - QR Code

    private func generateQRCode(from data: Data) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 5, y: 5))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

}

#Preview {
    YellowCardView()
        .modelContainer(for: [FamilyProfile.self, VaccinationRecord.self], inMemory: true)
}
