import Foundation
import SwiftData
import PDFKit
import CoreText

#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformFont = NSFont
#endif

// MARK: - Export DTO

struct ProfileExport: Codable {
    let name: String
    let relationship: String
    let dateOfBirth: String
    let records: [RecordExport]

    struct RecordExport: Codable {
        let vaccineName: String
        let manufacturer: String?
        let lotNumber: String?
        let dateAdministered: String
        let administeringProvider: String?
        let injectionSite: String?
        let notes: String?
    }
}

// MARK: - DataExportService

final class DataExportService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - JSON Export

    func exportAsJSON(profile: FamilyProfile) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let export = ProfileExport(
            name: profile.name,
            relationship: profile.relationship.rawValue,
            dateOfBirth: formatter.string(from: profile.dateOfBirth),
            records: profile.vaccinationRecords
                .sorted { $0.dateAdministered < $1.dateAdministered }
                .map { r in
                    ProfileExport.RecordExport(
                        vaccineName: r.vaccineName,
                        manufacturer: r.manufacturer,
                        lotNumber: r.lotNumber,
                        dateAdministered: formatter.string(from: r.dateAdministered),
                        administeringProvider: r.administeringProvider,
                        injectionSite: r.injectionSite,
                        notes: r.notes
                    )
                }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    // MARK: - PDF Export

    func exportAsPDF(profile: FamilyProfile) -> Data {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium

        let pageW: CGFloat = 612
        let pageH: CGFloat = 792
        let margin: CGFloat = 50
        let contentW = pageW - margin * 2

        let pdfData = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: pageW, height: pageH)

        guard let consumer = CGDataConsumer(data: pdfData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            return Data()
        }

        var y: CGFloat = pageH - margin

        func newPage() {
            if y < pageH - margin { ctx.endPage() }
            ctx.beginPage(mediaBox: &box)
            y = pageH - margin
        }

        func draw(_ text: String, size: CGFloat, bold: Bool = false) {
            let font = bold ? PlatformFont.boldSystemFont(ofSize: size) : PlatformFont.systemFont(ofSize: size)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let aStr = NSAttributedString(string: text, attributes: attrs)
            let fs = CTFramesetterCreateWithAttributedString(aStr)
            let h = ceil(CTFramesetterSuggestFrameSizeWithConstraints(
                fs, CFRange(location: 0, length: aStr.length), nil,
                CGSize(width: contentW, height: .greatestFiniteMagnitude), nil
            ).height)
            if y - h < margin { newPage() }
            let rect = CGRect(x: margin, y: y - h, width: contentW, height: h)
            let frame = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: aStr.length), CGPath(rect: rect, transform: nil), nil)
            CTFrameDraw(frame, ctx)
            y -= h + 4
        }

        newPage()
        draw("Immunization Report", size: 22, bold: true)
        y -= 8
        draw("Name: \(profile.name)", size: 14)
        draw("Date of Birth: \(dateFmt.string(from: profile.dateOfBirth))", size: 14)
        draw("Generated: \(dateFmt.string(from: Date()))", size: 10)
        y -= 16

        let records = profile.vaccinationRecords.sorted { $0.dateAdministered < $1.dateAdministered }
        if records.isEmpty {
            draw("No vaccination records on file.", size: 12)
        } else {
            for r in records {
                draw(r.vaccineName, size: 14, bold: true)
                draw("Date: \(dateFmt.string(from: r.dateAdministered))", size: 11)
                if let m = r.manufacturer { draw("Manufacturer: \(m)", size: 11) }
                if let l = r.lotNumber { draw("Lot #: \(l)", size: 11) }
                if let p = r.administeringProvider { draw("Provider: \(p)", size: 11) }
                y -= 12
            }
        }

        ctx.endPage()
        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Delete All Data

    func deleteAllData() throws {
        try context.delete(model: FamilyProfile.self)
        try context.delete(model: VaccinationRecord.self)
        try context.delete(model: SideEffectLog.self)
        try context.delete(model: SavedLocation.self)
        try context.delete(model: TravelPlan.self)
        try context.delete(model: AppSettings.self)
        try context.save()
        let _ = AppSettings.shared(in: context)
        try context.save()
    }
}

// MARK: - Yellow Card PDF Export

extension DataExportService {
    func exportYellowCardPDF(profile: FamilyProfile) -> Data {
        let records = profile.vaccinationRecords.sorted { $0.dateAdministered < $1.dateAdministered }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]

            var y: CGFloat = 40

            let title = "INTERNATIONAL CERTIFICATE OF VACCINATION OR PROPHYLAXIS"
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 30

            "Name: \(profile.name)".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 20

            let dobStr = profile.dateOfBirth.formatted(.dateTime.month(.wide).day().year())
            "Date of Birth: \(dobStr)".draw(at: CGPoint(x: 40, y: y), withAttributes: headerAttrs)
            y += 30

            let headers = ["Vaccine", "Date", "Provider", "Lot #"]
            let colX: [CGFloat] = [40, 200, 340, 480]
            for (i, header) in headers.enumerated() {
                header.draw(at: CGPoint(x: colX[i], y: y), withAttributes: headerAttrs)
            }
            y += 20

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            for record in records {
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

            let dateFmt = DateFormatter()
            dateFmt.dateStyle = .long
            y += 20
            "Generated: \(dateFmt.string(from: Date()))".draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
        }
    }
}
