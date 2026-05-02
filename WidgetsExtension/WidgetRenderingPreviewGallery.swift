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
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .frame(width: 170, height: 170)
}

#Preview("Stale / Full", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.stale)
        .frame(width: 170, height: 170)
}

#Preview("Unavailable / Full", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.unavailable)
        .frame(width: 170, height: 170)
}

#Preview("Placeholder / Full", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.stormRiskPlaceholder)
        .frame(width: 170, height: 170)
}

#Preview("Gallery / Full", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.noAlert)
        .frame(width: 170, height: 170)
}

#Preview("Normal / Tinted + AX", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .accented)
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 170, height: 170)
}

#Preview("Normal / Clear", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .vibrant)
        .frame(width: 170, height: 170)
}

#Preview("Normal / Light", traits: .sizeThatFitsLayout) {
    WidgetStormRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .preferredColorScheme(.light)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Normal", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Stale", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.stale)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Unavailable", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.unavailable)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Placeholder", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.severeRiskPlaceholder)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Gallery", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.noAlert)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Tinted + AX", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .accented)
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Clear", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .vibrant)
        .frame(width: 170, height: 170)
}

#Preview("Severe / Light", traits: .sizeThatFitsLayout) {
    WidgetSevereRiskSmallView(snapshot: WidgetPreviewFixtures.normal)
        .preferredColorScheme(.light)
        .frame(width: 170, height: 170)
}

#Preview("Combined / Normal", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.normal)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Multiple Alerts", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.multipleAlerts)
        .frame(width: 360, height: 170)
}

#Preview("Combined / No Alerts", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.noAlert)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Stale", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.stale)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Unavailable", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.unavailable)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Placeholder", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.combinedPlaceholder)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Gallery", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.multipleAlerts)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Tinted + AX", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .accented)
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Clear", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.normal)
        .environment(\.widgetRenderingMode, .vibrant)
        .frame(width: 360, height: 170)
}

#Preview("Combined / Light", traits: .sizeThatFitsLayout) {
    WidgetCombinedLargeView(snapshot: WidgetPreviewFixtures.normal)
        .preferredColorScheme(.light)
        .frame(width: 360, height: 170)
}
