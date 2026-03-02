import SwiftData
import SwiftUI

/// Unified export hub — consolidates PDF, text, and QR sharing from a single location.
struct ExportView: View {
    let profile: FamilyProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    private var sortedRecords: [VaccinationRecord] {
        profile.vaccinationRecords.sorted { $0.dateAdministered < $1.dateAdministered }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: profile.colorTag))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name).font(.headline)
                            Text("\(sortedRecords.count) record\(sortedRecords.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("Documents") {
                    Button { exportImmunizationReport() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Immunization Report")
                                Text("Complete vaccination records as PDF")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .disabled(sortedRecords.isEmpty)
                    .accessibilityHint("Export full immunization report as PDF")

                    Button { exportYellowCard() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yellow Card (ICV)")
                                Text("International Certificate of Vaccination")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.badge.clock.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .disabled(sortedRecords.isEmpty)
                    .accessibilityHint("Export international yellow card as PDF")
                }

                Section("Other Formats") {
                    ShareLink(item: exportText) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Plain Text")
                                Text("Copy-friendly text summary")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.plaintext")
                                .foregroundStyle(.green)
                        }
                    }
                    .accessibilityHint("Share records as plain text")

                    let smartRecords = sortedRecords.filter { $0.smartHealthCardData != nil }
                    if !smartRecords.isEmpty {
                        if let qrImages = generateQRImages(from: smartRecords), !qrImages.isEmpty {
                            let items = qrImages.map { TransferableImage(image: $0) }
                            ShareLink(items: items, preview: { _ in SharePreview("SMART Health Card QR") }) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SMART Health QR Codes")
                                        Text("Digital verification codes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "qrcode")
                                        .foregroundStyle(.purple)
                                }
                            }
                            .accessibilityHint("Share SMART Health Card QR codes")
                        }
                    }
                }

                if sortedRecords.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Records", systemImage: "doc.text")
                        } description: {
                            Text("Add vaccination records to enable exports.")
                        }
                    }
                }
            }
            .navigationTitle("Export Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Immunization Report PDF

    private func exportImmunizationReport() {
        let service = DataExportService(context: modelContext)
        let data = service.exportAsPDF(profile: profile)
        guard !data.isEmpty else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(profile.name)_Vaccination_Records.pdf")
        try? data.write(to: url)
        shareItems = [url]
        showingShareSheet = true
    }

    // MARK: - Yellow Card PDF

    private func exportYellowCard() {
        let service = DataExportService(context: modelContext)
        let data = service.exportYellowCardPDF(profile: profile)
        guard !data.isEmpty else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("YellowCard_\(profile.name).pdf")
        try? data.write(to: url)
        shareItems = [url]
        showingShareSheet = true
    }

    // MARK: - Plain Text

    private var exportText: String {
        let f = DateFormatter()
        f.dateStyle = .long
        var lines = [
            "Vaccination Records — \(profile.name)",
            "Relationship: \(profile.relationship.displayName)",
            "Date of Birth: \(f.string(from: profile.dateOfBirth))",
            "",
            "Records:"
        ]
        if sortedRecords.isEmpty {
            lines.append("  No records on file.")
        } else {
            for record in sortedRecords {
                var line = "  • \(record.vaccineName) — \(f.string(from: record.dateAdministered))"
                if let mfg = record.manufacturer, !mfg.isEmpty { line += " (\(mfg))" }
                if let lot = record.lotNumber, !lot.isEmpty { line += " [Lot: \(lot)]" }
                if let provider = record.administeringProvider, !provider.isEmpty { line += " — \(provider)" }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append("Exported from VaxNear on \(f.string(from: Date.now))")
        return lines.joined(separator: "\n")
    }

    // MARK: - QR Codes

    private func generateQRImages(from records: [VaccinationRecord]) -> [UIImage]? {
        records.compactMap { record -> UIImage? in
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
}

#Preview {
    ExportView(profile: FamilyProfile(name: "Test", relationship: .selfUser, dateOfBirth: .now))
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
