import SwiftUI
import WidgetKit

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

#Preview("Normal / Full", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.normal)
        .frame(width: 338, height: 158)
}

#Preview("No Alert / Full", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.noAlert)
        .frame(width: 338, height: 158)
}

#Preview("Stale / Full", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.stale)
        .frame(width: 338, height: 158)
}

#Preview("Unavailable / Full", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.unavailable)
        .frame(width: 338, height: 158)
}

#Preview("Multiple Alerts / Full", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.multipleAlerts)
        .frame(width: 338, height: 158)
}

#Preview("Normal / Tinted + AX", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .accented)
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 338, height: 158)
}

#Preview("Normal / Clear", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .vibrant)
        .frame(width: 338, height: 158)
}

#Preview("Normal / Light", traits: .sizeThatFitsLayout) {
    WidgetRenderingPreviewCard(snapshot: WidgetPreviewFixtures.normal)
        .preferredColorScheme(.light)
        .frame(width: 338, height: 158)
}
