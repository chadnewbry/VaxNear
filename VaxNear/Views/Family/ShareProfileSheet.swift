import SwiftUI

struct ShareProfileSheet: View {
    let profile: FamilyProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)

                Text("Share \(profile.name)'s Records")
                    .font(.title3.bold())

                Text("Generate a read-only summary of vaccination records to share with family members or healthcare providers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Text share
                ShareLink(item: exportText) {
                    Label("Share as Text", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)

                // PDF share
                if let pdfURL = generatePDF() {
                    ShareLink(item: pdfURL) {
                        Label("Share as PDF", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal, 32)
                }

                // QR Code share (SMART Health Cards)
                if let qrImages = generateQRImages(), !qrImages.isEmpty {
                    let items = qrImages.map { TransferableImage(image: $0) }
                    ShareLink(items: items, preview: { _ in SharePreview("SMART Health Card QR") }) {
                        Label("Share QR Codes", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Text Export

    private var exportText: String {
        var lines = [
            "Vaccination Records — \(profile.name)",
            "Relationship: \(profile.relationship.displayName)",
            "Date of Birth: \(formatted(profile.dateOfBirth))",
            "",
            "Records:"
        ]

        let sorted = profile.vaccinationRecords.sorted { $0.dateAdministered < $1.dateAdministered }
        if sorted.isEmpty {
            lines.append("  No records on file.")
        } else {
            for record in sorted {
                var line = "  • \(record.vaccineName) — \(formatted(record.dateAdministered))"
                if let mfg = record.manufacturer, !mfg.isEmpty {
                    line += " (\(mfg))"
                }
                if let lot = record.lotNumber, !lot.isEmpty {
                    line += " [Lot: \(lot)]"
                }
                if let provider = record.administeringProvider, !provider.isEmpty {
                    line += " — \(provider)"
                }
                lines.append(line)
            }
        }

        lines.append("")
        lines.append("Exported from VaxNear on \(formatted(Date.now))")
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF Export

    private func generatePDF() -> URL? {
        let service = DataExportService(context: modelContext)
        let data = service.exportAsPDF(profile: profile)
        guard !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(profile.name)_Vaccination_Records.pdf")
        try? data.write(to: url)
        return url
    }

    // MARK: - QR Code Export

    private func generateQRImages() -> [UIImage]? {
        let records = profile.vaccinationRecords.filter { $0.smartHealthCardData != nil }
        guard !records.isEmpty else { return nil }

        return records.compactMap { record -> UIImage? in
            guard let shcData = record.smartHealthCardData,
                  let shcString = String(data: shcData, encoding: .utf8),
                  let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
            filter.setValue(shcString.data(using: .ascii), forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel")
            guard let ciImage = filter.outputImage else { return nil }
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            return UIImage(ciImage: ciImage.transformed(by: transform))
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }
}

// MARK: - Transferable wrapper for UIImage ShareLink

struct TransferableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.image.pngData() ?? Data()
        }
    }
}

#Preview {
    ShareProfileSheet(profile: FamilyProfile(name: "Test", relationship: .selfUser, dateOfBirth: .now))
}
