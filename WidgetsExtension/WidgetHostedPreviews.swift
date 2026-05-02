import SwiftUI
import WidgetKit

#Preview("Storm / Normal", as: .systemSmall) {
    SkyAwareStormRiskWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Storm / High", as: .systemSmall) {
    SkyAwareStormRiskWidget()
} timeline: {
    Entry(
        date: .now,
        snapshot: WidgetSnapshot(
            generatedAt: WidgetPreviewFixtures.now,
            stormRisk: WidgetRiskDisplayState(label: "High Risk", severity: 6),
            severeRisk: WidgetRiskDisplayState(label: "Tornado", severity: 3),
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: WidgetPreviewFixtures.now, state: .fresh),
            availability: .available,
            destination: .summary
        )
    )
}

#Preview("Storm / Stale", as: .systemSmall) {
    SkyAwareStormRiskWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.stale)
}

#Preview("Storm / Unavailable", as: .systemSmall) {
    SkyAwareStormRiskWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.unavailable)
}

#Preview("Severe / None", as: .systemSmall) {
    SkyAwareSevereRiskWidget()
} timeline: {
    Entry(
        date: .now,
        snapshot: WidgetSnapshot(
            generatedAt: WidgetPreviewFixtures.now,
            stormRisk: WidgetRiskDisplayState(label: "Marginal Risk", severity: 0),
            severeRisk: WidgetRiskDisplayState(label: "No Active Threats", severity: 0),
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: WidgetPreviewFixtures.now, state: .fresh),
            availability: .available,
            destination: .summary
        )
    )
}

#Preview("Severe / Wind", as: .systemSmall) {
    SkyAwareSevereRiskWidget()
} timeline: {
    Entry(
        date: .now,
        snapshot: WidgetSnapshot(
            generatedAt: WidgetPreviewFixtures.now,
            stormRisk: WidgetRiskDisplayState(label: "Marginal Risk", severity: 2),
            severeRisk: WidgetRiskDisplayState(label: "Wind", severity: 1),
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: WidgetPreviewFixtures.now, state: .fresh),
            availability: .available,
            destination: .summary
        )
    )
}

#Preview("Severe / Hail", as: .systemSmall) {
    SkyAwareSevereRiskWidget()
} timeline: {
    Entry(
        date: .now,
        snapshot: WidgetSnapshot(
            generatedAt: WidgetPreviewFixtures.now,
            stormRisk: WidgetRiskDisplayState(label: "Slight Risk", severity: 3),
            severeRisk: WidgetRiskDisplayState(label: "Hail", severity: 2),
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: WidgetPreviewFixtures.now, state: .fresh),
            availability: .available,
            destination: .summary
        )
    )
}

#Preview("Severe / Tornado", as: .systemSmall) {
    SkyAwareSevereRiskWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Combined / Normal", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Combined / Multiple Alerts", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.multipleAlerts)
}

#Preview("Combined / No Alerts", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.noAlert)
}

#Preview("Combined / Stale", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.stale)
}

#Preview("Combined / Unavailable", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.unavailable)
}
