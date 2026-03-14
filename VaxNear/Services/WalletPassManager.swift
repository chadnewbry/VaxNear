import Foundation
import PassKit
import UIKit

@MainActor
final class WalletPassManager: ObservableObject {
    static let shared = WalletPassManager()

    @Published var lastError: String?

    var isWalletAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    // MARK: - Pass Data Structure

    /// Builds the pass JSON payload for a vaccination record.
    /// Note: Actual pass signing requires a Pass Type ID certificate configured
    /// in Apple Developer portal. This builds the unsigned pass.json structure.
    func buildPassPayload(for record: VaccinationRecord) -> [String: Any] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let secondaryFields: [[String: Any]] = [
            ["key": "manufacturer", "label": "MANUFACTURER", "value": record.manufacturer ?? "N/A"],
            ["key": "lot", "label": "LOT NUMBER", "value": record.lotNumber ?? "N/A"]
        ]

        var backFields: [[String: Any]] = [
            ["key": "provider", "label": "Healthcare Provider", "value": record.administeringProvider ?? "N/A"],
            ["key": "site", "label": "Injection Site", "value": record.injectionSite ?? "N/A"],
            ["key": "recordId", "label": "Record ID", "value": record.id.uuidString]
        ]

        if let notes = record.notes, !notes.isEmpty {
            backFields.append(["key": "notes", "label": "Notes", "value": notes])
        }

        if record.smartHealthCardData != nil {
            backFields.append(["key": "shc", "label": "SMART Health Card", "value": "QR code available on front of pass"])
        }

        var pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": "pass." + AppConfig.shared.bundleId,
            "serialNumber": record.id.uuidString,
            "teamIdentifier": "TEAM_ID",
            "organizationName": "VaxNear",
            "description": "\(record.vaccineName) Vaccination Card",
            "foregroundColor": "rgb(255, 255, 255)",
            "backgroundColor": "rgb(25, 75, 140)",
            "labelColor": "rgb(180, 210, 240)",
            "generic": [
                "headerFields": [["key": "date", "label": "DATE", "value": formatter.string(from: record.dateAdministered)]],
                "primaryFields": [["key": "vaccine", "label": "VACCINE", "value": record.vaccineName]],
                "secondaryFields": secondaryFields,
                "backFields": backFields
            ]
        ]

        if let shcData = record.smartHealthCardData {
            let shcString = String(data: shcData, encoding: .utf8) ?? ""
            pass["barcodes"] = [["format": "PKBarcodeFormatQR", "message": shcString, "messageEncoding": "iso-8859-1"]]
        }

        return pass
    }

    // MARK: - Generate Pass Bundle

    /// Creates a .pkpass bundle directory with pass.json and icons.
    /// The bundle must be signed with a Pass Type ID certificate before
    /// it can be added to Wallet.
    func generatePassBundle(for record: VaccinationRecord) throws -> URL {
        let passDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("passes")
            .appendingPathComponent(record.id.uuidString)

        try FileManager.default.createDirectory(at: passDir, withIntermediateDirectories: true)

        let payload = buildPassPayload(for: record)
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        try jsonData.write(to: passDir.appendingPathComponent("pass.json"))

        if let iconData = generatePassIcon(size: CGSize(width: 87, height: 87)) {
            try iconData.write(to: passDir.appendingPathComponent("icon@2x.png"))
        }
        if let iconData = generatePassIcon(size: CGSize(width: 129, height: 129)) {
            try iconData.write(to: passDir.appendingPathComponent("icon@3x.png"))
        }

        return passDir
    }

    // MARK: - Add to Wallet

    /// Presents PKAddPassesViewController for a signed .pkpass file.
    func addToWallet(passData: Data) throws {
        let pass = try PKPass(data: passData)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            lastError = "Unable to present wallet dialog."
            return
        }

        let addController = PKAddPassesViewController(pass: pass)
        let presentingVC = rootVC.presentedViewController ?? rootVC
        presentingVC.present(addController!, animated: true)
    }

    func isPassInWallet(for record: VaccinationRecord) -> Bool {
        let library = PKPassLibrary()
        return library.passes().contains { $0.serialNumber == record.id.uuidString }
    }

    // MARK: - Icon Generator

    private func generatePassIcon(size: CGSize) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 25/255, green: 75/255, blue: 140/255, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let crossWidth = size.width * 0.2
            let crossLength = size.width * 0.6
            let centerX = size.width / 2
            let centerY = size.height / 2

            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(
                x: centerX - crossLength / 2, y: centerY - crossWidth / 2,
                width: crossLength, height: crossWidth
            ), cornerRadius: crossWidth * 0.2).fill()
            UIBezierPath(roundedRect: CGRect(
                x: centerX - crossWidth / 2, y: centerY - crossLength / 2,
                width: crossWidth, height: crossLength
            ), cornerRadius: crossWidth * 0.2).fill()
        }
        return image.pngData()
    }
}
