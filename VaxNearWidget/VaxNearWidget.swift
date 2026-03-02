import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Shared Data

struct NextDueVaccine {
    let vaccineName: String
    let dueDate: Date
    let daysUntilDue: Int
    let profileName: String
    let recordId: UUID?
}

// MARK: - Timeline Entry

struct VaxNearEntry: TimelineEntry {
    let date: Date
    let nextDue: NextDueVaccine?
    let profileName: String
}

// MARK: - Configuration Intent

struct SelectProfileIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Profile"
    static var description: IntentDescription = "Choose which family profile to display"

    @Parameter(title: "Profile Name", default: "")
    var profileName: String
}

// MARK: - Timeline Provider

struct VaxNearTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = VaxNearEntry
    typealias Intent = SelectProfileIntent

    func placeholder(in context: Context) -> VaxNearEntry {
        VaxNearEntry(
            date: .now,
            nextDue: NextDueVaccine(
                vaccineName: "COVID-19 Booster",
                dueDate: Calendar.current.date(byAdding: .day, value: 14, to: .now)!,
                daysUntilDue: 14,
                profileName: "You",
                recordId: nil
            ),
            profileName: "You"
        )
    }

    func snapshot(for configuration: SelectProfileIntent, in context: Context) async -> VaxNearEntry {
        placeholder(in: context)
    }

    func timeline(for configuration: SelectProfileIntent, in context: Context) async -> Timeline<VaxNearEntry> {
        // Read from shared UserDefaults (app group)
        let defaults = UserDefaults(suiteName: "group.com.chadnewbry.vaxnear")
        let profileName = configuration.profileName.isEmpty
            ? (defaults?.string(forKey: "primaryProfileName") ?? "You")
            : configuration.profileName

        var nextDue: NextDueVaccine? = nil

        if let data = defaults?.data(forKey: "nextDueVaccine_\(profileName)") ?? defaults?.data(forKey: "nextDueVaccine"),
           let decoded = try? JSONDecoder().decode(NextDueData.self, from: data) {
            let days = Calendar.current.dateComponents([.day], from: .now, to: decoded.dueDate).day ?? 0
            nextDue = NextDueVaccine(
                vaccineName: decoded.vaccineName,
                dueDate: decoded.dueDate,
                daysUntilDue: max(0, days),
                profileName: profileName,
                recordId: decoded.recordId
            )
        }

        let entry = VaxNearEntry(date: .now, nextDue: nextDue, profileName: profileName)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Shared Codable for UserDefaults transport

struct NextDueData: Codable {
    let vaccineName: String
    let dueDate: Date
    let recordId: UUID?
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: VaxNearEntry

    var body: some View {
        if let next = entry.nextDue {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "cross.vial.fill")
                        .foregroundStyle(.blue)
                    Text("Next Due")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(next.vaccineName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer()

                Text(next.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(daysLabel(next.daysUntilDue))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(urgencyColor(next.daysUntilDue))
            }
            .padding()
            .widgetURL(next.recordId.map { DeepLink.recordDetail(id: $0).url } ?? DeepLink.records.url)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("All caught up!")
                    .font(.headline)
                Text("No upcoming vaccines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private func urgencyColor(_ days: Int) -> Color {
        if days <= 3 { return .red }
        if days <= 14 { return .orange }
        return .blue
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: VaxNearEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: next due info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.profileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let next = entry.nextDue {
                    Text(next.vaccineName)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(next.dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(daysLabel(next.daysUntilDue))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(urgencyColor(next.daysUntilDue))
                } else {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("All caught up!")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)
                .padding(.vertical, 12)

            // Right: Quick Find button
            Link(destination: DeepLink.finder().url) {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("Find\nVaccines")
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetURL(entry.nextDue?.recordId.map { DeepLink.recordDetail(id: $0).url } ?? DeepLink.records.url)
    }

    private func daysLabel(_ days: Int) -> String {
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private func urgencyColor(_ days: Int) -> Color {
        if days <= 3 { return .red }
        if days <= 14 { return .orange }
        return .blue
    }
}

// MARK: - Widget Definition

struct VaxNearNextDueWidget: Widget {
    let kind: String = "VaxNearNextDue"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectProfileIntent.self,
            provider: VaxNearTimelineProvider()
        ) { entry in
            switch entry.date {
            default:
                SmallWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            }
        }
        .configurationDisplayName("Next Due Vaccine")
        .description("Shows your next upcoming vaccination")
        .supportedFamilies([.systemSmall])
    }
}

struct VaxNearQuickFindWidget: Widget {
    let kind: String = "VaxNearQuickFind"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectProfileIntent.self,
            provider: VaxNearTimelineProvider()
        ) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Due + Quick Find")
        .description("See your next vaccine and quickly find locations")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct VaxNearWidgetBundle: WidgetBundle {
    var body: some Widget {
        VaxNearNextDueWidget()
        VaxNearQuickFindWidget()
    }
}
