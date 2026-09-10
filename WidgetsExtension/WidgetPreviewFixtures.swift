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
        locationSummary: "Norman, OK",
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
        locationSummary: "Bennett, CO",
        destination: .summary
    )

    static let combinedQuiet = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "No Severe Storm Risk", severity: 0),
        severeRisk: WidgetRiskDisplayState(label: "No Active Threats", severity: 0),
        selectedAlert: nil,
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-300), state: .fresh),
        availability: .available,
        locationSummary: "Boulder, CO",
        destination: .summary
    )

    static let stormQuiet = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "No Severe Storm Risk", severity: 0),
        severeRisk: WidgetRiskDisplayState(label: "No Active Threats", severity: 0),
        selectedAlert: nil,
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-300), state: .fresh),
        availability: .available,
        destination: .summary
    )

    static let severeQuiet = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "No Severe Storm Risk", severity: 0),
        severeRisk: WidgetRiskDisplayState(label: "No Active Threats", severity: 0),
        selectedAlert: nil,
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-300), state: .fresh),
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

    static let stormRiskPlaceholder = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "Slight Risk", severity: 3),
        severeRisk: WidgetRiskDisplayState(label: "Wind", severity: 1),
        selectedAlert: nil,
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-300), state: .fresh),
        availability: .available,
        destination: .summary
    )

    static let severeRiskPlaceholder = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "Marginal Risk", severity: 2),
        severeRisk: WidgetRiskDisplayState(label: "Hail", severity: 2),
        selectedAlert: nil,
        hiddenAlertCount: 0,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-300), state: .fresh),
        availability: .available,
        destination: .summary
    )

    static let combinedPlaceholder = WidgetSnapshot(
        generatedAt: now,
        stormRisk: WidgetRiskDisplayState(label: "Enhanced Risk", severity: 4),
        severeRisk: WidgetRiskDisplayState(label: "Tornado", severity: 3),
        selectedAlert: WidgetSelectedAlertRowDisplayState(
            title: "Tornado Watch 219",
            typeLabel: "Tornado Watch",
            severity: 5,
            issuedAt: now.addingTimeInterval(-900)
        ),
        hiddenAlertCount: 1,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-240), state: .fresh),
        availability: .available,
        locationSummary: "Oklahoma City, OK",
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
        activeAlerts: [
            WidgetSelectedAlertRowDisplayState(
                title: "Tornado Warning",
                typeLabel: "Tornado Warning",
                severity: 6,
                issuedAt: now.addingTimeInterval(-360),
                validEnd: now.addingTimeInterval(3_600)
            ),
            WidgetSelectedAlertRowDisplayState(
                title: "Severe Thunderstorm Warning",
                typeLabel: "Severe Thunderstorm Warning",
                severity: 4,
                issuedAt: now.addingTimeInterval(-480),
                validEnd: now.addingTimeInterval(5_400)
            ),
            WidgetSelectedAlertRowDisplayState(
                title: "Tornado Watch",
                typeLabel: "Tornado Watch",
                severity: 5,
                issuedAt: now.addingTimeInterval(-600),
                validEnd: now.addingTimeInterval(7_200)
            ),
            WidgetSelectedAlertRowDisplayState(
                title: "Flood Watch",
                typeLabel: "Flood Watch",
                severity: 3,
                issuedAt: now.addingTimeInterval(-720),
                validEnd: now.addingTimeInterval(9_000)
            ),
            WidgetSelectedAlertRowDisplayState(
                title: "Mesoscale Discussion 2032",
                typeLabel: "Mesoscale Discussion",
                severity: 2,
                issuedAt: now.addingTimeInterval(-840),
                validEnd: now.addingTimeInterval(10_800)
            )
        ],
        hiddenAlertCount: 4,
        freshness: WidgetFreshnessState(timestamp: now.addingTimeInterval(-180), state: .fresh),
        availability: .available,
        locationSummary: "Wichita Falls, TX",
        destination: .summary
    )

    static let threeAlerts = WidgetSnapshot(
        generatedAt: now,
        stormRisk: multipleAlerts.stormRisk,
        severeRisk: multipleAlerts.severeRisk,
        selectedAlert: multipleAlerts.selectedAlert,
        activeAlerts: Array(multipleAlerts.activeAlerts.prefix(3)),
        hiddenAlertCount: 0,
        freshness: multipleAlerts.freshness,
        availability: .available,
        locationSummary: multipleAlerts.locationSummary,
        destination: .summary
    )

    static let twoAlerts = WidgetSnapshot(
        generatedAt: now,
        stormRisk: multipleAlerts.stormRisk,
        severeRisk: multipleAlerts.severeRisk,
        selectedAlert: multipleAlerts.selectedAlert,
        activeAlerts: Array(multipleAlerts.activeAlerts.prefix(2)),
        hiddenAlertCount: 1,
        freshness: multipleAlerts.freshness,
        availability: .available,
        locationSummary: multipleAlerts.locationSummary,
        destination: .summary
    )

    static let all: [WidgetSnapshot] = [
        normal,
        noAlert,
        stormQuiet,
        severeQuiet,
        combinedQuiet,
        stale,
        unavailable,
        multipleAlerts,
        twoAlerts,
        threeAlerts,
        stormRiskPlaceholder,
        severeRiskPlaceholder,
        combinedPlaceholder
    ]
}
