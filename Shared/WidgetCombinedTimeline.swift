import Foundation

enum WidgetCombinedTimeline {
    static let minimumEntryInterval: TimeInterval = 5 * 60
    static let maximumEntryCount = 32

    struct State: Sendable {
        let date: Date
        let snapshot: WidgetSnapshot
        let relevance: WidgetSnapshotRelevance?
    }

    static func states(for snapshot: WidgetSnapshot, now: Date) -> [State] {
        var dates = [now]
        if case .available = snapshot.availability {
            let alerts = snapshot.activeAlerts.isEmpty
                ? snapshot.selectedAlert.map { [$0] } ?? []
                : snapshot.activeAlerts
            let boundaries = alerts.compactMap(\.validEnd).filter { $0 > now }.sorted()
            for boundary in boundaries {
                guard let previous = dates.last, boundary > previous else { continue }
                let earliest = previous.addingTimeInterval(minimumEntryInterval)
                // Coalesce nearby expirations into a later entry, never removing a valid alert early.
                // Reserve the final slot for all remaining expirations when the entry budget is full.
                if dates.count == maximumEntryCount - 1, let finalBoundary = boundaries.last {
                    dates.append(max(finalBoundary, earliest))
                    break
                }
                dates.append(max(boundary, earliest))
            }
        }
        // Always derive from the same accepted snapshot, rather than progressively truncating alerts.
        return dates.map { date in
            let normalized = snapshot.normalizedForWidgetPresentation(at: date)
            return State(
                date: date,
                snapshot: normalized,
                relevance: WidgetSnapshotRelevancePolicy.relevance(for: normalized, surface: .combined, now: date)
            )
        }
    }
}
