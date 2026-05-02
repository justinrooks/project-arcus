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
        var reloadedKinds: [String] = []
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
                watches: [],
                mesos: []
            )
        )

        #expect(store.load().snapshot?.freshness.timestamp == generatedAt)
        #expect(reloadedKinds == [
            SkyAwareWidgetKind.stormRisk,
            SkyAwareWidgetKind.severeRisk,
            SkyAwareWidgetKind.combined,
            SkyAwareWidgetKind.placeholder
        ])
    }

    @Test("alert projection writes snapshot and reloads combined kind only")
    func alertProjection_writesSnapshotAndReloadsCombinedOnly() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let generatedAt = Date(timeIntervalSince1970: 1_710)
        var reloadedKinds: [String] = []
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
                watches: [makeWatch(id: "watch-1", title: "Tornado Warning", now: generatedAt)],
                mesos: []
            )
        )

        #expect(store.load().snapshot?.selectedAlert?.title == "Tornado Warning")
        #expect(reloadedKinds == [
            SkyAwareWidgetKind.combined,
            SkyAwareWidgetKind.placeholder
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

private func makeWatch(id: String, title: String, now: Date) -> WatchRowDTO {
    WatchRowDTO(
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
