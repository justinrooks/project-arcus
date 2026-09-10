import SwiftUI
import WidgetKit

struct WidgetLargeAwarenessView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
                    .padding(16)
            } else {
                content
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .accessibilityElement(children: .contain)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local Awareness")
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                WidgetRiskBadgeView(
                    title: WidgetRiskKind.storm.title,
                    state: snapshot.stormRisk,
                    kind: .storm
                )
                WidgetRiskBadgeView(
                    title: WidgetRiskKind.severe.title,
                    state: snapshot.severeRisk,
                    kind: .severe
                )
            }

            if displayedAlerts.isEmpty {
                WidgetNoAlertStateView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(displayedAlerts.prefix(3).enumerated()), id: \.offset) { index, alert in
                        WidgetCompactAlertRowView(
                            alert: alert,
                            hiddenAlertCount: index == 0 ? largeHiddenAlertCount : 0
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(locationSummaryLine, systemImage: "mappin.and.ellipse")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                WidgetFreshnessLineView(freshness: snapshot.alertFreshness ?? snapshot.freshness)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private var displayedAlerts: [WidgetSelectedAlertRowDisplayState] {
        guard snapshot.activeAlerts.isEmpty else { return snapshot.activeAlerts }
        return snapshot.selectedAlert.map { [$0] } ?? []
    }

    private var largeHiddenAlertCount: Int {
        let knownAlertCount = max(snapshot.activeAlerts.count, snapshot.hiddenAlertCount + 1)
        return max(0, knownAlertCount - min(displayedAlerts.count, 3))
    }

    private var locationSummaryLine: String {
        let trimmed = snapshot.locationSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.flatMap { $0.isEmpty ? nil : $0 } ?? "Location unavailable"
    }
}
