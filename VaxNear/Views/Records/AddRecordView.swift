import Compression
import SwiftData
import SwiftUI

struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthKit = HealthKitManager.shared
    @Query(sort: \FamilyProfile.createdAt) private var profiles: [FamilyProfile]

    var assignToProfile: FamilyProfile?
    var existingRecord: VaccinationRecord?

    @State private var vaccineName = ""
    @State private var vaccineSearchText = ""
    @State private var manufacturer = ""
    @State private var lotNumber = ""
    @State private var dateAdministered = Date.now
    @State private var provider = ""
    @State private var injectionSite = "Left Arm"
    @State private var notes = ""
    @State private var selectedProfileID: UUID?
    @State private var showingQRScanner = false
    @State private var showingVaccinePicker = false

    private let siteOptions = ["Left Arm", "Right Arm", "Left Thigh", "Right Thigh", "Other"]
    private let cdcManager = CDCDataManager.shared

    private var isEditing: Bool { existingRecord != nil }

    private var vaccineSearchResults: [VaccineInfo] {
        guard !vaccineSearchText.isEmpty else { return cdcManager.allVaccines() }
        return cdcManager.searchVaccines(query: vaccineSearchText)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !profiles.isEmpty {
                    Section("Profile") {
                        Picker("For", selection: $selectedProfileID) {
                            Text("Unassigned").tag(nil as UUID?)
                            ForEach(profiles) { profile in
                                HStack {
                                    Circle().fill(Color(hex: profile.colorTag)).frame(width: 8, height: 8)
                                    Text(profile.name)
                                }.tag(profile.id as UUID?)
                            }
                        }
                    }
                }

                Section("Vaccine Information") {
                    Button {
                        showingVaccinePicker = true
                    } label: {
                        HStack {
                            Text("Vaccine")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(vaccineName.isEmpty ? "Select..." : vaccineName)
                                .foregroundStyle(vaccineName.isEmpty ? .tertiary : .secondary)
                        }
                    }
                    .accessibilityLabel("Vaccine")
                    .accessibilityValue(vaccineName.isEmpty ? "Not selected" : vaccineName)
                    .accessibilityHint("Double tap to select a vaccine")

                    TextField("Manufacturer (optional)", text: $manufacturer)
                        .accessibilityLabel("Manufacturer")
                    TextField("Lot Number (optional)", text: $lotNumber)
                        .accessibilityLabel("Lot number")
                }

                Section("Administration") {
                    DatePicker("Date", selection: $dateAdministered, displayedComponents: .date)
                    TextField("Provider / Clinic (optional)", text: $provider)
                        .accessibilityLabel("Provider or clinic")
                    Picker("Injection Site", selection: $injectionSite) {
                        ForEach(siteOptions, id: \.self) { Text($0) }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .accessibilityLabel("Notes")
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        showingQRScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityHint("Open camera to scan a SMART Health Card QR code")
                }
            }
            .navigationTitle(isEditing ? "Edit Record" : "Add Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecord() }
                        .disabled(vaccineName.isEmpty)
                        .accessibilityHint(vaccineName.isEmpty ? "Select a vaccine first" : "Save this vaccination record")
                }
            }
            .onAppear {
                selectedProfileID = assignToProfile?.id
                if let record = existingRecord {
                    vaccineName = record.vaccineName
                    manufacturer = record.manufacturer ?? ""
                    lotNumber = record.lotNumber ?? ""
                    dateAdministered = record.dateAdministered
                    provider = record.administeringProvider ?? ""
                    injectionSite = record.injectionSite ?? "Left Arm"
                    notes = record.notes ?? ""
                    selectedProfileID = record.profile?.id
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerView { scannedData in
                    handleQRData(scannedData)
                    showingQRScanner = false
                }
            }
            .sheet(isPresented: $showingVaccinePicker) {
                vaccinePickerSheet
            }
        }
    }

    // MARK: - Vaccine Picker

    private var vaccinePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(vaccineSearchResults, id: \.name) { vaccine in
                    Button {
                        vaccineName = vaccine.name
                        if manufacturer.isEmpty {
                            manufacturer = vaccine.manufacturer
                        }
                        showingVaccinePicker = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vaccine.name).font(.body).foregroundStyle(.primary)
                            if !vaccine.alternateNames.isEmpty {
                                Text(vaccine.alternateNames.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(vaccine.manufacturer) · \(vaccine.type)")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .searchable(text: $vaccineSearchText, prompt: "Search vaccines...")
            .navigationTitle("Select Vaccine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingVaccinePicker = false }
                }
            }
        }
    }

    // MARK: - Save

    private func saveRecord() {
        let profile = profiles.first { $0.id == selectedProfileID }

        if let existing = existingRecord {
            existing.vaccineName = vaccineName
            existing.manufacturer = manufacturer.isEmpty ? nil : manufacturer
            existing.lotNumber = lotNumber.isEmpty ? nil : lotNumber
            existing.dateAdministered = dateAdministered
            existing.administeringProvider = provider.isEmpty ? nil : provider
            existing.injectionSite = injectionSite
            existing.notes = notes.isEmpty ? nil : notes
            existing.profile = profile
        } else {
            let record = VaccinationRecord(
                vaccineName: vaccineName,
                manufacturer: manufacturer.isEmpty ? nil : manufacturer,
                lotNumber: lotNumber.isEmpty ? nil : lotNumber,
                dateAdministered: dateAdministered,
                administeringProvider: provider.isEmpty ? nil : provider,
                injectionSite: injectionSite,
                notes: notes.isEmpty ? nil : notes
            )
            record.profile = profile
            modelContext.insert(record)

            // Decrement free uses
            let settings = AppSettings.shared(in: modelContext)
            if !settings.hasPurchasedFullVersion {
                settings.freeUsesRemaining = max(0, settings.freeUsesRemaining - 1)
            }

            // Schedule booster reminder
            let notificationManager = NotificationManager()
            notificationManager.configure(modelContext: modelContext)
            notificationManager.scheduleBoosterReminder(for: record)

            // Write to HealthKit
            Task { try? await healthKit.syncRecord(record) }
        }

        dismiss()
    }

    // MARK: - QR Handling

    private func handleQRData(_ data: String) {
        // SMART Health Card QR codes start with "shc:/"
        guard data.hasPrefix("shc:/") else { return }

        // Decode numeric-encoded JWS
        let numericPart = String(data.dropFirst(5))
        let chars = Array(numericPart)
        var jws = ""
        var i = 0
        while i + 1 < chars.count {
            if let num = Int(String(chars[i]) + String(chars[i + 1])) {
                jws.append(Character(UnicodeScalar(num + 45)!))
            }
            i += 2
        }

        // Decode JWS payload (second segment, base64url, DEFLATE compressed)
        let segments = jws.split(separator: ".")
        guard segments.count >= 2 else { return }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let payloadData = Data(base64Encoded: base64),
              let decompressed = decompressDeflate(payloadData),
              let json = try? JSONSerialization.jsonObject(with: decompressed) as? [String: Any],
              let vc = json["vc"] as? [String: Any],
              let credSubject = vc["credentialSubject"] as? [String: Any],
              let fhirBundle = credSubject["fhirBundle"] as? [String: Any],
              let entries = fhirBundle["entry"] as? [[String: Any]] else { return }

        for entry in entries {
            guard let resource = entry["resource"] as? [String: Any],
                  resource["resourceType"] as? String == "Immunization" else { continue }

            if let vaccineCode = resource["vaccineCode"] as? [String: Any],
               let codings = vaccineCode["coding"] as? [[String: Any]],
               let display = codings.first?["display"] as? String {
                vaccineName = display
            }

            if let occurrenceDate = resource["occurrenceDateTime"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                if let date = formatter.date(from: occurrenceDate) {
                    dateAdministered = date
                }
            }

            if let lotNumberValue = resource["lotNumber"] as? String {
                lotNumber = lotNumberValue
            }

            break
        }
    }

    private func decompressDeflate(_ data: Data) -> Data? {
        let bufferSize = 65_536

        let result = data.withUnsafeBytes { srcBuffer -> Data? in
            guard let srcPtr = srcBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }

            let decodedSize = compression_decode_buffer(
                dstBuffer, bufferSize,
                srcPtr, data.count,
                nil,
                COMPRESSION_ZLIB
            )

            guard decodedSize > 0 else { return nil }
            return Data(bytes: dstBuffer, count: decodedSize)
        }

        return result
    }
}

#Preview {
    AddRecordView()
}
