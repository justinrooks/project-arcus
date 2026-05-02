import Foundation

enum SkyAwareWidgetKind {
    static let placeholder = "SkyAwarePlaceholderWidget"
    static let stormRisk = "SkyAwareStormRiskWidget"
    static let severeRisk = "SkyAwareSevereRiskWidget"
    static let combined = "SkyAwareCombinedWidget"

    static let allSnapshotBacked: [String] = [
        stormRisk,
        severeRisk,
        combined
    ]
}
