import Foundation
import Testing
@testable import SkyAware

@Suite("Widget Snapshot Refresh Coordinator")
struct WidgetSnapshotRefreshCoordinatorTests {
    @Test("risk projection writes snapshot and reloads risk + combined kinds")
    func riskProjection_writesSnapshotAndReloadsTargetedKinds() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let generatedAt = Date(timeIntervalSince1970: 1_700)
        let reloadedKinds = ReloadedKindsRecorder()
        let coordinator = WidgetSnapshotRefreshCoordinator(
            store: store,
            reloadTimeline: { reloadedKinds.append($0) }
        )

        try coordinator.refresh(
            scope: .riskOrLocationProjection,
            input: .init(
                generatedAt: generatedAt,
                stormRisk: .enhanced,
                severeRisk: .tornado(probability: 0.1),
                alerts: [],
                mesos: [],
                locationSummary: "Denver, CO"
            )
        )

        #expect(store.load().snapshot?.freshness.timestamp == generatedAt)
        #expect(store.load().snapshot?.locationSummary == "Denver, CO")
        #expect(reloadedKinds.values() == [
            SkyAwareWidgetKind.stormRisk,
            SkyAwareWidgetKind.severeRisk,
            SkyAwareWidgetKind.combined,
            SkyAwareWidgetKind.stormRiskLockScreen,
            SkyAwareWidgetKind.severeRiskLockScreen
        ])
    }

    @Test("alert projection writes snapshot and reloads combined kind only")
    func alertProjection_writesSnapshotAndReloadsCombinedOnly() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let generatedAt = Date(timeIntervalSince1970: 1_710)
        let reloadedKinds = ReloadedKindsRecorder()
        let coordinator = WidgetSnapshotRefreshCoordinator(
            store: store,
            reloadTimeline: { reloadedKinds.append($0) }
        )

        try coordinator.refresh(
            scope: .activeAlertProjection,
            input: .init(
                generatedAt: generatedAt,
                stormRisk: .marginal,
                severeRisk: .wind(probability: 0.2),
                alerts: [makeAlert(id: "watch-1", title: "Tornado Warning", now: generatedAt)],
                mesos: [],
                locationSummary: "Norman, OK"
            )
        )

        #expect(store.load().snapshot?.selectedAlert?.title == "Tornado Warning")
        #expect(store.load().snapshot?.locationSummary == "Norman, OK")
        #expect(reloadedKinds.values() == [
            SkyAwareWidgetKind.combined
        ])
    }

    @Test("risk projection overwrites stale tornado state with all clear")
    func riskProjection_overwritesStaleTornadoStateWithAllClear() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let reloadedKinds = ReloadedKindsRecorder()
        let coordinator = WidgetSnapshotRefreshCoordinator(
            store: store,
            reloadTimeline: { reloadedKinds.append($0) }
        )

        try coordinator.refresh(
            scope: .riskOrLocationProjection,
            input: .init(
                generatedAt: Date(timeIntervalSince1970: 1_700),
                stormRisk: .marginal,
                severeRisk: .tornado(probability: 0.02),
                alerts: [],
                mesos: [],
                locationSummary: "Bennett, CO"
            )
        )
        try coordinator.refresh(
            scope: .riskOrLocationProjection,
            input: .init(
                generatedAt: Date(timeIntervalSince1970: 1_760),
                stormRisk: .marginal,
                severeRisk: .allClear,
                alerts: [],
                mesos: [],
                locationSummary: "Bennett, CO"
            )
        )

        #expect(store.load().snapshot?.severeRisk == .init(label: "No Active Threats", severity: 0))
        #expect(Array(reloadedKinds.values().suffix(5)) == [
            SkyAwareWidgetKind.stormRisk,
            SkyAwareWidgetKind.severeRisk,
            SkyAwareWidgetKind.combined,
            SkyAwareWidgetKind.stormRiskLockScreen,
            SkyAwareWidgetKind.severeRiskLockScreen
        ])
    }

    @Test("remote APNs plans are excluded from normal ingestion widget refresh scope")
    func homeWidgetRefreshScope_excludesRemoteHotAlertPlans() {
        let remoteReceivedPlan = HomeIngestionPlan(request: .init(trigger: .remoteHotAlertReceived))
        let remoteOpenedPlan = HomeIngestionPlan(request: .init(trigger: .remoteHotAlertOpened))
        let foregroundPlan = HomeIngestionPlan(request: .init(trigger: .foregroundActivate))

        #expect(homeWidgetRefreshScope(for: remoteReceivedPlan) == nil)
        #expect(homeWidgetRefreshScope(for: remoteOpenedPlan) == nil)
        #expect(homeWidgetRefreshScope(for: foregroundPlan) == .riskOrLocationProjection)
    }

    private func makeSandboxDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private final class ReloadedKindsRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ kind: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(kind)
    }

    func values() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private func makeAlert(id: String, title: String, now: Date) -> AlertDTO {
    AlertDTO(
        id: id,
        messageId: nil,
        currentRevisionSent: nil,
        title: title,
        headline: title,
        issued: now.addingTimeInterval(-600),
        expires: now.addingTimeInterval(600),
        ends: now.addingTimeInterval(600),
        messageType: "Alert",
        sender: nil,
        severity: "Severe",
        urgency: "Immediate",
        certainty: "Observed",
        description: "Alert",
        instruction: nil,
        response: nil,
        areaSummary: "Area",
        geometryData: nil,
        tornadoDetection: nil,
        tornadoDamageThreat: nil,
        maxWindGust: nil,
        maxHailSize: nil,
        windThreat: nil,
        hailThreat: nil,
        thunderstormDamageThreat: nil,
        flashFloodDetection: nil,
        flashFloodDamageThreat: nil
    )
}

private extension WidgetSnapshotStoreLoadResult {
    var snapshot: WidgetSnapshot? {
        guard case .snapshot(let snapshot) = self else { return nil }
        return snapshot
    }
}
