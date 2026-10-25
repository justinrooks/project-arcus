import Foundation
import Synchronization
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reserved at the accepted-state owner, before any suspension can reorder publishers.
/// This is process-local ordering only: no publisher survives an app process restart.
struct WidgetSnapshotPublication: Sendable, Equatable {
    private static let sequence = Mutex<UInt64>(0)
    let order: UInt64
    let projection: HomeProjectionRecord

    init(projection: HomeProjectionRecord) {
        self.projection = projection
        self.order = Self.sequence.withLock { value in
            value += 1
            return value
        }
    }
}

struct WidgetSnapshotRefreshInput: Sendable {
    let publication: WidgetSnapshotPublication?
    let generatedAt: Date
    let riskSnapshotTimestamp: Date?
    let alertSnapshotTimestamp: Date?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let alerts: [AlertDTO]
    let mesos: [MdDTO]
    let locationSummary: String?

    init(
        generatedAt: Date,
        publication: WidgetSnapshotPublication? = nil,
        snapshotTimestamp: Date? = nil,
        riskSnapshotTimestamp: Date? = nil,
        alertSnapshotTimestamp: Date? = nil,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel? = nil,
        alerts: [AlertDTO],
        mesos: [MdDTO],
        locationSummary: String?
    ) {
        self.publication = publication
        self.generatedAt = generatedAt
        self.riskSnapshotTimestamp = riskSnapshotTimestamp ?? snapshotTimestamp
        self.alertSnapshotTimestamp = alertSnapshotTimestamp ?? snapshotTimestamp
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.alerts = alerts
        self.mesos = mesos
        self.locationSummary = locationSummary
    }

    init(
        publication: WidgetSnapshotPublication,
        generatedAt: Date,
        riskSnapshotTimestamp: Date? = nil
    ) {
        let record = publication.projection
        self.init(
            generatedAt: generatedAt,
            publication: publication,
            riskSnapshotTimestamp: riskSnapshotTimestamp ?? record.lastSlowProductsLoadAt,
            alertSnapshotTimestamp: record.lastHotAlertsLoadAt,
            stormRisk: record.stormRisk,
            severeRisk: record.severeRisk,
            fireRisk: record.fireRisk,
            alerts: record.activeAlerts,
            mesos: record.activeMesos,
            locationSummary: record.placemarkSummary
        )
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
                fireRisk: input.fireRisk,
                alerts: input.alerts,
                mesos: input.mesos,
                locationSummary: input.locationSummary
            ),
            now: input.generatedAt
        )
        guard try store.write(snapshot, publicationOrder: input.publication?.order) else { return }
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
