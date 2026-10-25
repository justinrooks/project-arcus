import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("Widget Snapshot Refresh Coordinator")
@MainActor
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
                fireRisk: .extreme,
                alerts: [],
                mesos: [],
                locationSummary: "Denver, CO"
            )
        )

        #expect(store.load().snapshot?.freshness.timestamp == generatedAt)
        #expect(store.load().snapshot?.locationSummary == "Denver, CO")
        #expect(store.load().snapshot?.fireRisk == .init(label: "Extreme Fire Risk", severity: 10))
        #expect(reloadedKinds.values() == [
            SkyAwareWidgetKind.stormRisk,
            SkyAwareWidgetKind.severeRisk,
            SkyAwareWidgetKind.combined,
            SkyAwareWidgetKind.stormRiskLockScreen,
            SkyAwareWidgetKind.severeRiskLockScreen
        ])
    }

    @Test("risk and alert freshness remain domain-specific")
    func refresh_preservesDomainSpecificFreshness() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let riskLoadedAt = Date(timeIntervalSince1970: 1_600)
        let alertsLoadedAt = Date(timeIntervalSince1970: 1_700)
        let coordinator = WidgetSnapshotRefreshCoordinator(store: store)

        try coordinator.refresh(
            scope: .riskOrLocationProjection,
            input: .init(
                generatedAt: alertsLoadedAt,
                riskSnapshotTimestamp: riskLoadedAt,
                alertSnapshotTimestamp: alertsLoadedAt,
                stormRisk: .enhanced,
                severeRisk: .allClear,
                alerts: [],
                mesos: [],
                locationSummary: nil
            )
        )

        let snapshot = try #require(store.load().snapshot)
        #expect(snapshot.freshness.timestamp == riskLoadedAt)
        #expect(snapshot.alertFreshness?.timestamp == alertsLoadedAt)
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

    @Test("static widget fixture seeding requires opt-in and persists the warning")
    func staticWidgetFixtureSeeding_requiresExplicitOptIn() throws {
        let sandbox = try makeSandboxDirectory()
        let store = WidgetSnapshotStore(directoryURL: sandbox)
        let reloadedKinds = ReloadedKindsRecorder()
        let coordinator = WidgetSnapshotRefreshCoordinator(
            store: store,
            reloadTimeline: { reloadedKinds.append($0) }
        )
        let generatedAt = Date()

        try SkyAwareApp.seedUITestWidgetSnapshotIfNeeded(
            environment: ["UI_TESTS_STATIC_HOME": "1"],
            generatedAt: generatedAt,
            widgetSnapshotRefresher: coordinator
        )
        #expect(store.load().snapshot == nil)
        #expect(reloadedKinds.values().isEmpty)

        try SkyAwareApp.seedUITestWidgetSnapshotIfNeeded(
            environment: [
                "UI_TESTS_STATIC_HOME": "1",
                "UI_TESTS_STATIC_WIDGETS": "1"
            ],
            generatedAt: generatedAt,
            widgetSnapshotRefresher: coordinator
        )

        let snapshot = try #require(store.load().snapshot)
        #expect(snapshot.selectedAlert?.title == "Severe Thunderstorm Warning")
        #expect(snapshot.stormRisk.label == "Enhanced Risk")
        #expect(snapshot.severeRisk.label == "Tornado")
        #expect(snapshot.availability == .available)
        #expect(snapshot.locationSummary == "Norman, OK")
        #expect(snapshot.freshness.timestamp == generatedAt)
        #expect(snapshot.alertFreshness?.timestamp == generatedAt)
        #expect(reloadedKinds.values() == SkyAwareWidgetKind.allSnapshotBacked)
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

    @Test("static widget fixtures block ingestion snapshot overwrites only when fully opted in")
    func staticWidgetFixtures_blockIngestionOverwritesOnlyWhenFullyOptedIn() {
        #expect(
            shouldRefreshHomeWidgetsForEnvironment([
                "UI_TESTS_STATIC_HOME": "1",
                "UI_TESTS_STATIC_WIDGETS": "1"
            ]) == false
        )
        #expect(shouldRefreshHomeWidgetsForEnvironment(["UI_TESTS_STATIC_HOME": "1"]))
        #expect(shouldRefreshHomeWidgetsForEnvironment(["UI_TESTS_STATIC_WIDGETS": "1"]))
        #expect(shouldRefreshHomeWidgetsForEnvironment([:]))
    }

    @Test("delayed remote A cannot overwrite accepted B", arguments: [false, true])
    func delayedRemotePublication_preservesAcceptedWinner(changesLocation: Bool) async throws {
        let sandbox = try makeSandboxDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let file = WidgetSnapshotStore(directoryURL: sandbox)
        let reloads = ReloadedKindsRecorder()
        let coordinator = WidgetSnapshotRefreshCoordinator(store: file, reloadTimeline: { reloads.append($0) })
        let projections = HomeProjectionStore(modelContainer: try TestStore.container(for: [HomeProjection.self]))
        let time = Date(timeIntervalSince1970: 10_000)
        let first = widgetContext(cell: 1, name: "A")
        _ = try await projections.commitCore(
            .init(slowProducts: (.enhanced, .tornado(probability: 0.1), .critical),
                  hotAlerts: ([makeAlert(id: "A", title: "Tornado Warning", now: time)], [])),
            for: first, loadedAt: time
        )
        let gate = WidgetPublicationGate()
        // Match production: independent coordinators and stores share one app-group destination.
        let remoteCoordinator = WidgetSnapshotRefreshCoordinator(
            store: WidgetSnapshotStore(directoryURL: sandbox), reloadTimeline: { reloads.append($0) }
        )
        let remote = RemoteAlertWidgetSnapshotRefreshDriver(projectionStore: projections, widgetSnapshotRefresher: remoteCoordinator)
        await remote.setPublicationCheckpointForTesting { await gate.pause() }
        // A's generatedAt is later than B's: writer clock time cannot establish source order.
        let delayed = Task { try await remote.refreshFromLatestProjection(generatedAt: time.addingTimeInterval(120)) }
        await gate.waitUntilPaused()
        let second = changesLocation ? widgetContext(cell: 2, name: "B") : first
        // Equal accepted timestamps exercise source revisions independently of wall-clock ordering.
        let accepted = try await projections.commitCore(
            .init(slowProducts: (.marginal, .allClear, .clear), hotAlerts: ([], [])),
            for: second, loadedAt: time
        )
        let publication = accepted.widgetPublication
        try coordinator.refresh(scope: .riskOrLocationProjection, input: .init(publication: publication, generatedAt: time))
        let winner = try #require(file.load().snapshot)
        let reloadCount = reloads.values().count
        await gate.release()
        try await delayed.value
        #expect(file.load().snapshot == winner)
        #expect(winner.locationSummary == second.snapshot.placemarkSummary)
        #expect(winner.selectedAlert == nil)
        #expect(winner.stormRisk.label == "Marginal Risk")
        #expect(winner.severeRisk.label == "No Active Threats")
        #expect(reloads.values().count == reloadCount)

        // Legitimate receipt and repeated publication of this accepted source still reload Combined.
        await remote.setPublicationCheckpointForTesting(nil)
        // Read the same source explicitly: cross-location timestamp ties retain the reader's existing tie policy.
        let repeatDriver = RemoteAlertWidgetSnapshotRefreshDriver(
            projectionStore: WidgetPublicationReader(publication: publication), widgetSnapshotRefresher: remoteCoordinator
        )
        try await repeatDriver.refreshFromLatestProjection(generatedAt: time.addingTimeInterval(1))
        #expect(reloads.values().last == SkyAwareWidgetKind.combined)
        #expect(reloads.values().count == reloadCount + 1)

        _ = try await projections.commitCore(
            .init(hotAlerts: ([makeAlert(id: "C", title: "Tornado Warning", now: time)], [])),
            for: second, loadedAt: time.addingTimeInterval(60)
        )
        try await remote.refreshFromLatestProjection(generatedAt: time.addingTimeInterval(120))
        let updated = try #require(file.load().snapshot)
        #expect(updated.selectedAlert?.title == "Tornado Warning")
        #expect(updated.locationSummary == second.snapshot.placemarkSummary)
        #expect(updated.stormRisk == winner.stormRisk)
        #expect(updated.freshness.timestamp == time)
        #expect(updated.alertFreshness?.timestamp == time.addingTimeInterval(60))
        #expect(reloads.values().count == reloadCount + 2)
    }

    @Test("competing publishers preserve the newest source and whole-file freshness")
    func competingPublishers_preserveNewestSource() async throws {
        let sandbox = try makeSandboxDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let file = WidgetSnapshotStore(directoryURL: sandbox)
        let coordinator = WidgetSnapshotRefreshCoordinator(store: file, reloadTimeline: { _ in })
        let projections = HomeProjectionStore(modelContainer: try TestStore.container(for: [HomeProjection.self]))
        let time = Date(timeIntervalSince1970: 10_000)
        let context = widgetContext(cell: 1, name: "A")
        let first = try await projections.commitCore(
            .init(slowProducts: (.enhanced, .tornado(probability: 0.1), .critical), hotAlerts: ([], [])),
            for: context, loadedAt: time
        )
        let second = try await projections.commitCore(
            .init(hotAlerts: ([makeAlert(id: "B", title: "Tornado Warning", now: time)], [])),
            for: context, loadedAt: time.addingTimeInterval(60)
        )
        let older = first.widgetPublication
        let newer = second.widgetPublication
        let competingCoordinator = WidgetSnapshotRefreshCoordinator(
            store: WidgetSnapshotStore(directoryURL: sandbox), reloadTimeline: { _ in }
        )
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                group.addTask {
                    let writer = index.isMultiple(of: 2) ? coordinator : competingCoordinator
                    try writer.refresh(
                        scope: .activeAlertProjection,
                        input: .init(publication: index.isMultiple(of: 2) ? older : newer, generatedAt: time.addingTimeInterval(120))
                    )
                }
            }
            try await group.waitForAll()
        }
        let snapshot = try #require(file.load().snapshot)
        #expect(snapshot.selectedAlert?.title == "Tornado Warning")
        #expect(snapshot.stormRisk.label == "Enhanced Risk")
        #expect(snapshot.freshness.timestamp == time)
        #expect(snapshot.alertFreshness?.timestamp == time.addingTimeInterval(60))
    }

    @Test("reselecting cached A publishes after B and rejects delayed B")
    func cachedLocationReselection_reservesNewOrder() async throws {
        let sandbox = try makeSandboxDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let file = WidgetSnapshotStore(directoryURL: sandbox)
        let reloads = ReloadedKindsRecorder()
        let home = WidgetSnapshotRefreshCoordinator(store: file, reloadTimeline: { reloads.append($0) })
        let remote = WidgetSnapshotRefreshCoordinator(
            store: WidgetSnapshotStore(directoryURL: sandbox), reloadTimeline: { reloads.append($0) }
        )
        let projections = HomeProjectionStore(modelContainer: try TestStore.container(for: [HomeProjection.self]))
        let time = Date(timeIntervalSince1970: 10_000)
        let contextA = widgetContext(cell: 1, name: "A")
        let a = try await projections.commitCore(
            .init(slowProducts: (.enhanced, .tornado(probability: 0.1), .critical), hotAlerts: ([], [])),
            for: contextA, loadedAt: time
        )
        try home.refresh(scope: .riskOrLocationProjection, input: .init(publication: a.widgetPublication, generatedAt: time))
        let b = try await projections.commitCore(
            .init(slowProducts: (.marginal, .allClear, .clear), hotAlerts: ([], [])),
            for: widgetContext(cell: 2, name: "B"), loadedAt: time.addingTimeInterval(60)
        )
        try remote.refresh(scope: .activeAlertProjection, input: .init(publication: b.widgetPublication, generatedAt: time))
        let selectedA = try #require(await projections.widgetPublication(for: contextA))
        try home.refresh(scope: .riskOrLocationProjection, input: .init(publication: selectedA, generatedAt: time))
        let winner = try #require(file.load().snapshot)
        #expect(winner.locationSummary == "A")
        #expect(winner.stormRisk.label == "Enhanced Risk")
        #expect(Array(reloads.values().suffix(SkyAwareWidgetKind.allSnapshotBacked.count)) == SkyAwareWidgetKind.allSnapshotBacked)
        let reloadCount = reloads.values().count
        try remote.refresh(scope: .activeAlertProjection, input: .init(publication: b.widgetPublication, generatedAt: time))
        #expect(file.load().snapshot == winner)
        #expect(reloads.values().count == reloadCount)
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

private actor WidgetPublicationReader: LatestHomeProjectionReading {
    let publication: WidgetSnapshotPublication
    init(publication: WidgetSnapshotPublication) { self.publication = publication }
    func latestProjectionForWidgetSnapshotRefresh() -> HomeProjectionRecord? { publication.projection }
    func latestWidgetPublication() -> WidgetSnapshotPublication? { publication }
}

private actor WidgetPublicationGate {
    private var paused = false
    private var entered: CheckedContinuation<Void, Never>?
    private var resume: CheckedContinuation<Void, Never>?
    func pause() async {
        paused = true
        entered?.resume()
        entered = nil
        await withCheckedContinuation { resume = $0 }
    }
    func waitUntilPaused() async {
        if !paused { await withCheckedContinuation { entered = $0 } }
    }
    func release() { resume?.resume(); resume = nil }
}

private func widgetContext(cell: Int64, name: String) -> LocationContext {
    let snapshot = LocationSnapshot(
        coordinates: .init(latitude: 39.75, longitude: -104.44),
        timestamp: Date(timeIntervalSince1970: 100), accuracy: 25, placemarkSummary: name, h3Cell: cell
    )
    let grid = GridPointSnapshot(
        nwsId: "BOU/10,20", latitude: 39.75, longitude: -104.44, gridId: "BOU", gridX: 10, gridY: 20,
        forecastURL: nil, forecastHourlyURL: nil, forecastGridDataURL: nil, observationStationsURL: nil,
        city: name, state: "CO", timeZoneId: "America/Denver", radarStationId: nil,
        forecastZone: "COZ038", countyCode: "COC005", fireZone: "COZ214", countyLabel: nil, fireZoneLabel: nil
    )
    return LocationContext(snapshot: snapshot, h3Cell: cell, grid: grid)
}
