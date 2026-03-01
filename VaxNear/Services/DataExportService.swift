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
