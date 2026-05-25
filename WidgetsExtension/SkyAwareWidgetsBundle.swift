import SwiftUI
import WidgetKit

@main
struct SkyAwareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SkyAwareStormRiskWidget()
        SkyAwareSevereRiskWidget()
        SkyAwareCombinedWidget()
        SkyAwareStormRiskLockScreenWidget()
        SkyAwareSevereRiskLockScreenWidget()
    }
}

struct SkyAwareStormRiskWidget: Widget {
    private let kind = SkyAwareWidgetKind.stormRisk

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StormRiskProvider()) { entry in
            SkyAwareStormRiskWidgetView(entry: entry)
                .widgetURL(WidgetRouteURL.url(for: entry.snapshot.destination))
        }
        .configurationDisplayName(WidgetGalleryMetadata.stormRiskName)
        .description(WidgetGalleryMetadata.stormRiskDescription)
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct SkyAwareSevereRiskWidget: Widget {
    private let kind = SkyAwareWidgetKind.severeRisk

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SevereRiskProvider()) { entry in
            SkyAwareSevereRiskWidgetView(entry: entry)
                .widgetURL(WidgetRouteURL.url(for: entry.snapshot.destination))
        }
        .configurationDisplayName(WidgetGalleryMetadata.severeRiskName)
        .description(WidgetGalleryMetadata.severeRiskDescription)
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct SkyAwareCombinedWidget: Widget {
    private let kind = SkyAwareWidgetKind.combined

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CombinedProvider()) { entry in
            SkyAwareCombinedWidgetView(entry: entry)
                .widgetURL(WidgetRouteURL.url(for: entry.snapshot.destination))
        }
        .configurationDisplayName(WidgetGalleryMetadata.combinedName)
        .description(WidgetGalleryMetadata.combinedDescription)
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct SkyAwareStormRiskLockScreenWidget: Widget {
    private let kind = SkyAwareWidgetKind.stormRiskLockScreen

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StormRiskProvider()) { entry in
            SkyAwareStormRiskLockScreenWidgetView(entry: entry)
                .widgetURL(WidgetRouteURL.url(for: entry.snapshot.destination))
        }
        .configurationDisplayName("Storm Risk")
        .description("Quick storm risk status on your Lock Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct SkyAwareSevereRiskLockScreenWidget: Widget {
    private let kind = SkyAwareWidgetKind.severeRiskLockScreen

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SevereRiskProvider()) { entry in
            SkyAwareSevereRiskLockScreenWidgetView(entry: entry)
                .widgetURL(WidgetRouteURL.url(for: entry.snapshot.destination))
        }
        .configurationDisplayName("Severe Risk")
        .description("Quick severe threat status on your Lock Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

private struct StormRiskProvider: TimelineProvider {
    private static let passiveRefreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: WidgetPreviewFixtures.stormRiskPlaceholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: currentSnapshot(now: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date.now
        let snapshot = currentSnapshot(now: now)
        let entry = Entry(date: now, snapshot: snapshot)
        let refreshDate = now.addingTimeInterval(Self.passiveRefreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func currentSnapshot(now: Date) -> WidgetSnapshot {
        guard
            let store = try? WidgetSnapshotStore(),
            case .snapshot(let snapshot) = store.load()
        else {
            return WidgetSnapshot.unavailable(generatedAt: now, timestamp: nil, destination: .summary)
        }

        return normalizeFreshness(snapshot, now: now)
    }

    private func normalizeFreshness(_ snapshot: WidgetSnapshot, now: Date) -> WidgetSnapshot {
        snapshot.normalizedForWidgetPresentation(at: now)
    }
}

private struct SevereRiskProvider: TimelineProvider {
    private static let passiveRefreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: WidgetPreviewFixtures.severeRiskPlaceholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: currentSnapshot(now: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date.now
        let snapshot = currentSnapshot(now: now)
        let entry = Entry(date: now, snapshot: snapshot)
        let refreshDate = now.addingTimeInterval(Self.passiveRefreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func currentSnapshot(now: Date) -> WidgetSnapshot {
        guard
            let store = try? WidgetSnapshotStore(),
            case .snapshot(let snapshot) = store.load()
        else {
            return WidgetSnapshot.unavailable(generatedAt: now, timestamp: nil, destination: .summary)
        }

        return normalizeFreshness(snapshot, now: now)
    }

    private func normalizeFreshness(_ snapshot: WidgetSnapshot, now: Date) -> WidgetSnapshot {
        snapshot.normalizedForWidgetPresentation(at: now)
    }
}

private struct CombinedProvider: TimelineProvider {
    private static let passiveRefreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: WidgetPreviewFixtures.combinedPlaceholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: currentSnapshot(now: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date.now
        let snapshot = currentSnapshot(now: now)
        let entry = Entry(date: now, snapshot: snapshot)
        let refreshDate = now.addingTimeInterval(Self.passiveRefreshInterval)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func currentSnapshot(now: Date) -> WidgetSnapshot {
        guard
            let store = try? WidgetSnapshotStore(),
            case .snapshot(let snapshot) = store.load()
        else {
            return WidgetSnapshot.unavailable(generatedAt: now, timestamp: nil, destination: .summary)
        }

        return normalizeFreshness(snapshot, now: now)
    }

    private func normalizeFreshness(_ snapshot: WidgetSnapshot, now: Date) -> WidgetSnapshot {
        snapshot.normalizedForWidgetPresentation(at: now)
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SkyAwareStormRiskWidgetView: View {
    let entry: Entry

    var body: some View {
        WidgetStormRiskSmallView(snapshot: entry.snapshot)
    }
}

struct SkyAwareSevereRiskWidgetView: View {
    let entry: Entry

    var body: some View {
        WidgetSevereRiskSmallView(snapshot: entry.snapshot)
    }
}

struct SkyAwareCombinedWidgetView: View {
    let entry: Entry

    var body: some View {
        WidgetCombinedLargeView(snapshot: entry.snapshot)
    }
}

struct SkyAwareStormRiskLockScreenWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        StormRiskAccessoryView(snapshot: entry.snapshot, family: family)
            .containerBackground(for: .widget) {
                Color.clear
            }
    }
}

struct SkyAwareSevereRiskLockScreenWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        SevereRiskAccessoryView(snapshot: entry.snapshot, family: family)
            .containerBackground(for: .widget) {
                Color.clear
            }
    }
}

private struct StormRiskAccessoryView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .storm, severity: snapshot.stormRisk.severity)
    }

    var body: some View {
        Group {
            if isUnavailable {
                unavailableView
            } else {
                contentView
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isUnavailable: Bool {
        if case .unavailable = snapshot.availability {
            return true
        }
        return false
    }

    @ViewBuilder
    private var unavailableView: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "exclamationmark.triangle")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("SkyAware")
                        .lineLimit(1)
                    Text("Unavailable")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            Text("SkyAware unavailable")
        default:
            Text("SkyAware unavailable")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: style.icon)
                .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: style.icon)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(compactStormLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("Storm Risk")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            Text(stormInlinePhrase)
        default:
            Text(stormInlinePhrase)
        }
    }

    private var compactStormLabel: String {
        let label = normalizedStormBaseLabel
        guard label.hasSuffix(" Risk") else { return label }
        return String(label.dropLast(" Risk".count))
    }

    private var normalizedStormBaseLabel: String {
        switch snapshot.stormRisk.severity {
        case 0:
            return "All Clear"
        case 1:
            return "Thunderstorm"
        default:
            return snapshot.stormRisk.label
        }
    }

    private var stormInlinePhrase: String {
        switch snapshot.stormRisk.severity {
        case 0:
            return "All clear"
        case 1:
            return "Thunderstorm risk"
        default:
            return "\(compactStormLabel) storm risk"
        }
    }

    private var accessibilityLabel: String {
        if isUnavailable {
            return "Storm Risk, unavailable"
        }
        return "Storm Risk, \(normalizedStormBaseLabel)"
    }
}

private struct SevereRiskAccessoryView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    private var style: WidgetRiskVisualStyle {
        WidgetRiskVisualStyle.style(for: .severe, severity: snapshot.severeRisk.severity)
    }

    var body: some View {
        Group {
            if isUnavailable {
                unavailableView
            } else {
                contentView
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isUnavailable: Bool {
        if case .unavailable = snapshot.availability {
            return true
        }
        return false
    }

    @ViewBuilder
    private var unavailableView: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "exclamationmark.triangle")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("SkyAware")
                        .lineLimit(1)
                    Text("Unavailable")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            Text("SkyAware unavailable")
        default:
            Text("SkyAware unavailable")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: style.icon)
                .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: style.icon)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(severePrimaryLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("Severe Risk")
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            Text(severeInlinePhrase)
        default:
            Text(severeInlinePhrase)
        }
    }

    private var severePrimaryLabel: String {
        if snapshot.severeRisk.severity == 0 {
            return "No Active"
        }
        return snapshot.severeRisk.label
    }

    private var severeInlinePhrase: String {
        switch snapshot.severeRisk.severity {
        case 3:
            return "Tornado possible"
        case 2:
            return "Hail possible"
        case 1:
            return "Damaging wind possible"
        default:
            return "No active severe threats"
        }
    }

    private var accessibilityLabel: String {
        if isUnavailable {
            return "Severe Risk, unavailable"
        }
        if snapshot.severeRisk.severity == 0 {
            return "Severe Risk, no active threats"
        }
        return "Severe Risk, \(severeInlinePhrase)"
    }
}
