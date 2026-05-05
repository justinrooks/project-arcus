import SwiftUI
import WidgetKit

// Keep this file free of #Preview blocks.
// Widget extension targets only support WidgetKit-hosted previews, which live in WidgetHostedPreviews.swift.

struct WidgetRenderingPreviewCard: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case let .unavailable(message) = snapshot.availability {
                WidgetUnavailableStateView(message: message)
            } else {
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

                if let selectedAlert = snapshot.selectedAlert {
                    WidgetCompactAlertRowView(
                        alert: selectedAlert,
                        hiddenAlertCount: snapshot.hiddenAlertCount
                    )
                } else {
                    WidgetNoAlertStateView()
                }

                if snapshot.freshness.state == .stale {
                    WidgetStaleStateView(freshness: snapshot.freshness)
                } else {
                    WidgetFreshnessLineView(freshness: snapshot.freshness)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.10, blue: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
