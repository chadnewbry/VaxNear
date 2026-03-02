import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

struct YellowCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]
    @Query(sort: \VaccinationRecord.dateAdministered) private var records: [VaccinationRecord]
    @State private var selectedProfileID: UUID?
    @State private var showingShareSheet = false
    @State private var pdfURL: URL?

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
                        exportPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
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

    // MARK: - PDF Export

    private func exportPDF() {
        guard let profile = selectedProfile else { return }
        let exportService = DataExportService(context: modelContext)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]

            var y: CGFloat = 40

            let title = "INTERNATIONAL CERTIFICATE OF VACCINATION OR PROPHYLAXIS"
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 30

            "Name: \(profile.name)".draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
            y += 20

            let dobStr = profile.dateOfBirth.formatted(.dateTime.month(.wide).day().year())
            "Date of Birth: \(dobStr)".draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
            y += 30

            // Table header
            let headers = ["Vaccine", "Date", "Provider", "Lot #"]
            let colX: [CGFloat] = [40, 200, 340, 480]
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: colX[i], y: y), withAttributes: attrs)
            }
            y += 20

            // Records
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            for record in profileRecords {
                record.vaccineName.draw(at: CGPoint(x: colX[0], y: y), withAttributes: bodyAttrs)
                dateFormatter.string(from: record.dateAdministered).draw(at: CGPoint(x: colX[1], y: y), withAttributes: bodyAttrs)
                (record.administeringProvider ?? "—").draw(at: CGPoint(x: colX[2], y: y), withAttributes: bodyAttrs)
                (record.lotNumber ?? "—").draw(at: CGPoint(x: colX[3], y: y), withAttributes: bodyAttrs)
                y += 16
                if y > 740 {
                    ctx.beginPage()
                    y = 40
                }
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("YellowCard_\(profile.name).pdf")
        try? data.write(to: tempURL)
        pdfURL = tempURL
        showingShareSheet = true
    }
}

#Preview {
    YellowCardView()
        .modelContainer(for: [FamilyProfile.self, VaccinationRecord.self], inMemory: true)
}
