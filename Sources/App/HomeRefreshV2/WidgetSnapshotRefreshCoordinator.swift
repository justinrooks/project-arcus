import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshotRefreshInput: Sendable {
    let generatedAt: Date
    let snapshotTimestamp: Date?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let alerts: [AlertDTO]
    let mesos: [MdDTO]
    let locationSummary: String?

    init(
        generatedAt: Date,
        snapshotTimestamp: Date? = nil,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        alerts: [AlertDTO],
        mesos: [MdDTO],
        locationSummary: String?
    ) {
        self.generatedAt = generatedAt
        self.snapshotTimestamp = snapshotTimestamp
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.alerts = alerts
        self.mesos = mesos
        self.locationSummary = locationSummary
    }
}

enum WidgetSnapshotChangeScope: Sendable {
    case riskOrLocationProjection
    case activeAlertProjection
}

protocol WidgetSnapshotRefreshing {
    func refresh(scope: WidgetSnapshotChangeScope, input: WidgetSnapshotRefreshInput) throws
}

struct WidgetSnapshotRefreshCoordinator: WidgetSnapshotRefreshing {
    typealias ReloadTimeline = (String) -> Void

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
                snapshotTimestamp: input.snapshotTimestamp ?? input.generatedAt,
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
