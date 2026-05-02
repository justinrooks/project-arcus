import SwiftUI
import WidgetKit

@main
struct SkyAwareWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SkyAwareStormRiskWidget()
    }
}

struct SkyAwareStormRiskWidget: Widget {
    private let kind = SkyAwareWidgetKind.stormRisk

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StormRiskProvider()) { entry in
            SkyAwareStormRiskWidgetView(entry: entry)
        }
        .configurationDisplayName("Storm Risk")
        .description("See current local storm risk.")
        .supportedFamilies([.systemSmall])
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
        guard case .available = snapshot.availability else {
            return snapshot
        }

        let normalizedFreshness: WidgetFreshnessState
        if let timestamp = snapshot.freshness.timestamp {
            normalizedFreshness = .from(timestamp: timestamp, now: now)
        } else {
            normalizedFreshness = snapshot.freshness
        }

        return WidgetSnapshot(
            generatedAt: snapshot.generatedAt,
            stormRisk: snapshot.stormRisk,
            severeRisk: snapshot.severeRisk,
            selectedAlert: snapshot.selectedAlert,
            hiddenAlertCount: snapshot.hiddenAlertCount,
            freshness: normalizedFreshness,
            availability: snapshot.availability,
            destination: snapshot.destination
        )
    }
}

private struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct SkyAwareStormRiskWidgetView: View {
    let entry: Entry

    var body: some View {
        WidgetStormRiskSmallView(snapshot: entry.snapshot)
    }
}
