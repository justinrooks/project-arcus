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

#Preview("Storm / All Clear", as: .systemSmall) {
    SkyAwareStormRiskWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.stormAllClear)
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

#Preview("Combined / Normal", as: .systemMedium) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Combined / Normal (Large)", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Combined / Multiple Alerts", as: .systemMedium) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.multipleAlerts)
}

#Preview("Combined / Multiple Alerts (Large)", as: .systemLarge) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.multipleAlerts)
}

#Preview("Combined / All Clear", as: .systemMedium) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.combinedAllClear)
}

#Preview("Combined / No Alerts", as: .systemMedium) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.noAlert)
}

#Preview("Combined / Stale", as: .systemMedium) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.stale)
}

#Preview("Combined / Unavailable", as: .systemMedium) {
    SkyAwareCombinedWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.unavailable)
}

#Preview("Storm Lock / Circular", as: .accessoryCircular) {
    SkyAwareStormRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Storm Lock / Rectangular", as: .accessoryRectangular) {
    SkyAwareStormRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Storm Lock / Inline", as: .accessoryInline) {
    SkyAwareStormRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Storm Lock / All Clear", as: .accessoryRectangular) {
    SkyAwareStormRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.stormAllClear)
}

#Preview("Storm Lock / Unavailable", as: .accessoryInline) {
    SkyAwareStormRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.unavailable)
}

#Preview("Severe Lock / Circular", as: .accessoryCircular) {
    SkyAwareSevereRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Severe Lock / Rectangular", as: .accessoryRectangular) {
    SkyAwareSevereRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Severe Lock / Inline", as: .accessoryInline) {
    SkyAwareSevereRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.normal)
}

#Preview("Severe Lock / No Active", as: .accessoryRectangular) {
    SkyAwareSevereRiskLockScreenWidget()
} timeline: {
    Entry(
        date: .now,
        snapshot: WidgetSnapshot(
            generatedAt: WidgetPreviewFixtures.now,
            stormRisk: WidgetRiskDisplayState(label: "Marginal Risk", severity: 2),
            severeRisk: WidgetRiskDisplayState(label: "No Active Threats", severity: 0),
            selectedAlert: nil,
            hiddenAlertCount: 0,
            freshness: WidgetFreshnessState(timestamp: WidgetPreviewFixtures.now, state: .fresh),
            availability: .available,
            destination: .summary
        )
    )
}

#Preview("Severe Lock / Unavailable", as: .accessoryInline) {
    SkyAwareSevereRiskLockScreenWidget()
} timeline: {
    Entry(date: .now, snapshot: WidgetPreviewFixtures.unavailable)
}
