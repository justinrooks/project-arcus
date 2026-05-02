import Foundation

enum WidgetPreviewFixtures {
    static let now = Date(timeIntervalSince1970: 1_778_013_240) // May 1, 2026 18:14:00 UTC

    static let normal = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "Enhanced Risk", severity: 4),
        severeRisk: WidgetRiskDisplayState(label: "Tornado", severity: 3),
        selectedAlert: WidgetSelectedAlertRowDisplayState(
            title: "Tornado Watch 219",
            typeLabel: "Tornado Watch",
            severity: 5,
            issuedAt: now.addingTimeInterval(-1_200)
        ),
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now, state: .fresh),
        availability: .available,
        destination: .summary
    )

    static let noAlert = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "Slight Risk", severity: 3),
        severeRisk: WidgetRiskDisplayState(label: "Wind", severity: 1),
        selectedAlert: nil,
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-420), state: .fresh),
        availability: .available,
        destination: .summary
    )

    static let stale = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "Moderate Risk", severity: 5),
        severeRisk: WidgetRiskDisplayState(label: "Hail", severity: 2),
        selectedAlert: WidgetSelectedAlertRowDisplayState(
            title: "Severe Thunderstorm Warning",
            typeLabel: "Severe Thunderstorm Warning",
            severity: 4,
            issuedAt: now.addingTimeInterval(-2_400)
        ),
        hiddenAlertCount: 1,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-2_100), state: .stale),
        availability: .available,
        destination: .summary
    )

    static let unavailable = WidgetSnapshot.unavailable(
        generatedAt: now,
        timestamp: now.addingTimeInterval(-3_600),
        destination: .summary
    )

    static let multipleAlerts = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "High Risk", severity: 6),
        severeRisk: WidgetRiskDisplayState(label: "Tornado", severity: 3),
        selectedAlert: WidgetSelectedAlertRowDisplayState(
            title: "Tornado Warning",
            typeLabel: "Tornado Warning",
            severity: 6,
            issuedAt: now.addingTimeInterval(-360)
        ),
        hiddenAlertCount: 3,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-180), state: .fresh),
        availability: .available,
        destination: .summary
    )

    static let all: [WidgetSnapshot] = [
        normal,
        noAlert,
        stale,
        unavailable,
        multipleAlerts
    ]
}
