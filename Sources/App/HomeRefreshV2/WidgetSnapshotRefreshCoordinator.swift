import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshotRefreshInput: Sendable {
    let generatedAt: Date
    let riskSnapshotTimestamp: Date?
    let alertSnapshotTimestamp: Date?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let alerts: [AlertDTO]
    let mesos: [MdDTO]
    let locationSummary: String?

    init(
        generatedAt: Date,
        snapshotTimestamp: Date? = nil,
        riskSnapshotTimestamp: Date? = nil,
        alertSnapshotTimestamp: Date? = nil,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        alerts: [AlertDTO],
        mesos: [MdDTO],
        locationSummary: String?
    ) {
        self.generatedAt = generatedAt
        self.riskSnapshotTimestamp = riskSnapshotTimestamp ?? snapshotTimestamp
        self.alertSnapshotTimestamp = alertSnapshotTimestamp ?? snapshotTimestamp
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.alerts = alerts
        self.mesos = mesos
        self.locationSummary = locationSummary
    }

    var snapshotTimestamp: Date? {
        alertSnapshotTimestamp ?? riskSnapshotTimestamp
    }
}

enum WidgetSnapshotChangeScope: Sendable {
    case riskOrLocationProjection
    case activeAlertProjection
}

protocol WidgetSnapshotRefreshing: Sendable {
    func refresh(scope: WidgetSnapshotChangeScope, input: WidgetSnapshotRefreshInput) throws
}

struct WidgetSnapshotRefreshCoordinator: WidgetSnapshotRefreshing {
    typealias ReloadTimeline = @Sendable (String) -> Void

    private let builder: WidgetSnapshotBuilder
    private let store: WidgetSnapshotStore
    private let reloadTimeline: ReloadTimeline

    init(
        builder: WidgetSnapshotBuilder = WidgetSnapshotBuilder(),
        store: WidgetSnapshotStore,
        reloadTimeline: @escaping ReloadTimeline = { kind in
            WidgetSnapshotRefreshCoordinator.defaultReloadTimeline(ofKind: kind)
        }
    ) {
        self.builder = builder
        self.store = store
        self.reloadTimeline = reloadTimeline
    }

    func refresh(scope: WidgetSnapshotChangeScope, input: WidgetSnapshotRefreshInput) throws {
        let snapshot = builder.build(
            from: .init(
                generatedAt: input.generatedAt,
                riskSnapshotTimestamp: input.riskSnapshotTimestamp ?? input.generatedAt,
                alertSnapshotTimestamp: input.alertSnapshotTimestamp,
                availability: .available,
                stormRisk: input.stormRisk,
                severeRisk: input.severeRisk,
                alerts: input.alerts,
                mesos: input.mesos,
                locationSummary: input.locationSummary
            ),
            now: input.generatedAt
        )
        try store.write(snapshot)
        for kind in affectedKinds(for: scope) {
            reloadTimeline(kind)
        }
    }

    private func affectedKinds(for scope: WidgetSnapshotChangeScope) -> [String] {
        switch scope {
        case .riskOrLocationProjection:
            return SkyAwareWidgetKind.allSnapshotBacked
        case .activeAlertProjection:
            return [SkyAwareWidgetKind.combined]
        }
    }

    private static func defaultReloadTimeline(ofKind kind: String) {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        #endif
    }
}
