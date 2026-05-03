import SwiftUI
import WidgetKit

@main
struct SkyAwareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SkyAwareStormRiskWidget()
        SkyAwareSevereRiskWidget()
        SkyAwareCombinedWidget()
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
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
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
