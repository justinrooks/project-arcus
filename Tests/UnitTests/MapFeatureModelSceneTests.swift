import CoreLocation
import Foundation
import ArcusCore
import MapKit
import Testing
@testable import SkyAware

@Suite("MapFeatureModel Scene")
@MainActor
struct MapFeatureModelSceneTests {
    private let now = Date(timeIntervalSince1970: 1_735_689_600) // Jan 1, 2025 00:00:00 UTC

    @Test("only map, meso, and alert accepted feeds invalidate the map")
    func acceptedFeedInvalidation_isScopedToVisibleMapInputs() {
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "spc.map.convective"))
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "spc.map.fire"))
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "spc.meso"))
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "arcus.alert"))
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "arcus.alerts"))
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "spc.outlook") == false)
        #expect(MapFeatureModel.shouldReload(forAcceptedFeedID: "home.projection") == false)
    }

    @Test("accepted feed events reach the map observer and reload map data")
    func acceptedFeedEvent_triggersMapReload() async throws {
        let store = FeedStateStore(directoryURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("MapFeedObserverTests")
            .appendingPathComponent(UUID().uuidString))
        let updates = await store.acceptedGenerationUpdates()
        let counter = MapDataCallCounter()
        let service = CountingSpcMapData(counter: counter, severeRisks: [], stormRisk: [], mesos: [], fireRisk: [])
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))
        var observed: [FeedStateGenerationUpdate] = []
        let (reloads, reloadContinuation) = AsyncStream<Void>.makeStream()
        var reloadIterator = reloads.makeAsyncIterator()
        let observer = Task { @MainActor in
            await MapFeatureModel.observeAcceptedFeedUpdates(from: updates) { update in
                observed.append(update)
                await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
                reloadContinuation.yield(())
            }
        }

        let now = Date(timeIntervalSince1970: 1_735_689_600)
        _ = try await store.update(.init(feedID: "spc.outlook", attemptedAt: now, canonicalAcceptedAt: now))
        _ = try await store.update(.init(feedID: "spc.map.convective", attemptedAt: now, canonicalAcceptedAt: now))
        _ = await reloadIterator.next()
        observer.cancel()

        #expect(observed == [FeedStateGenerationUpdate(feedID: "spc.map.convective", generation: 1)])
        let counts = await counter.snapshot()
        #expect(counts.storm == 1)
        #expect(counts.severe == 1)
        #expect(counts.meso == 1)
        #expect(counts.fire == 1)
    }

    @Test("scene cache retains only the two most recently used layers")
    func sceneCache_retainsTwoMostRecentlyUsedLayers() {
        var cache = MapSceneCache()

        cache.insert(.placeholder(for: .categorical), for: .categorical)
        cache.insert(.placeholder(for: .wind), for: .wind)
        #expect(cache.layers == [.categorical, .wind])

        #expect(cache.scene(for: .categorical)?.legendState.layer == .categorical)
        #expect(cache.layers == [.wind, .categorical])

        cache.insert(.placeholder(for: .hail), for: .hail)

        #expect(cache.layers == [.categorical, .hail])
        #expect(cache.scene(for: .wind) == nil)
        #expect(cache.scene(for: .categorical)?.legendState.layer == .categorical)
        #expect(cache.scene(for: .hail)?.legendState.layer == .hail)
    }

    @Test("selectLayer reuses cached scenes and rematerializes deterministic evictions")
    func selectLayer_reusesCachedScenesAndRematerializesEvictions() async throws {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([]),
            fireRisk: .success([
                FireRiskDTO(
                    product: "WindRH",
                    issued: now,
                    expires: now.addingTimeInterval(3_600),
                    valid: now,
                    riskLevel: 8,
                    riskLevelDescription: "Critical",
                    label: "Critical Fire Weather Area",
                    stroke: "#123456",
                    fill: "#ABCDEF",
                    polygons: [makeGeoPolygon(title: "Critical Fire Weather Area")]
                )
            ])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        let initialCategoricalOverlay = try #require(model.activeScene.canvasState.overlays.first?.overlay)
        model.selectLayer(.fire)

        let scene = model.activeScene
        #expect(scene.legendState.layer == .fire)
        #expect(scene.legendState.fireItems.map(\.riskLevel) == [8])
        #expect(scene.canvasState.overlays.count == 1)
        #expect(scene.canvasState.overlays.first?.key.contains("fire|8|") == true)

        let initialFireOverlay = try #require(scene.canvasState.overlays.first?.overlay)
        model.selectLayer(.categorical)
        let cachedCategoricalOverlay = try #require(model.activeScene.canvasState.overlays.first?.overlay)
        #expect(
            ObjectIdentifier(cachedCategoricalOverlay as AnyObject) ==
                ObjectIdentifier(initialCategoricalOverlay as AnyObject)
        )

        model.selectLayer(.fire)
        let cachedFireOverlay = try #require(model.activeScene.canvasState.overlays.first?.overlay)
        #expect(
            ObjectIdentifier(cachedFireOverlay as AnyObject) == ObjectIdentifier(initialFireOverlay as AnyObject)
        )

        model.selectLayer(.wind)
        model.selectLayer(.categorical)
        let rematerializedCategoricalOverlay = try #require(model.activeScene.canvasState.overlays.first?.overlay)
        #expect(
            ObjectIdentifier(rematerializedCategoricalOverlay as AnyObject) !=
                ObjectIdentifier(initialCategoricalOverlay as AnyObject)
        )
    }

    @Test("categorical overlays preserve low-to-high severity stacking")
    func categoricalOverlays_preserveSeverityStacking() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([
                makeStormRisk(level: .moderate, title: "MDT"),
                makeStormRisk(level: .thunderstorm, title: "TSTM"),
                makeStormRisk(level: .enhanced, title: "ENH"),
                makeStormRisk(level: .slight, title: "SLGT"),
                makeStormRisk(level: .marginal, title: "MRGL")
            ]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)

        #expect(overlayTitles(in: model.activeScene) == ["TSTM", "MRGL", "SLGT", "ENH", "MDT"])
    }

    @Test("severe overlays preserve low-to-high probability stacking for each threat layer")
    func severeOverlays_preserveProbabilityStacking() async {
        for (layer, type) in [(MapLayer.wind, ThreatType.wind), (.hail, .hail), (.tornado, .tornado)] {
            let model = MapFeatureModel()
            let service = StubSpcMapData(
                severeRisks: .success([
                    makeSevereRisk(type: type, probability: .percent(0.15), title: "15% \(type.displayName) Risk"),
                    makeSevereRisk(type: type, probability: .percent(0.05), title: "5% \(type.displayName) Risk"),
                    makeSevereRisk(type: type, probability: .significant(10), title: "10% Significant \(type.displayName) Risk"),
                    makeSevereRisk(type: type, probability: .percent(0.10), title: "10% \(type.displayName) Risk")
                ]),
                stormRisk: .success([]),
                mesos: .success([]),
                fireRisk: .success([])
            )
            let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

            await model.reload(using: service, warningSource: warnings, selectedLayer: layer)

            #expect(
                overlayTitles(in: model.activeScene) == [
                    "5% \(type.displayName) Risk",
                    "10% \(type.displayName) Risk",
                    "10% Significant \(type.displayName) Risk",
                    "15% \(type.displayName) Risk"
                ]
            )
        }
    }

    @Test("reload refetches map products on each call")
    func reload_refetchesEachTime() async {
        let counter = MapDataCallCounter()
        let service = CountingSpcMapData(
            counter: counter,
            severeRisks: [],
            stormRisk: [makeStormRisk(level: .slight, title: "SLGT")],
            mesos: [],
            fireRisk: []
        )
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        await model.reload(using: service, warningSource: warnings, selectedLayer: .fire)

        let counts = await counter.snapshot()
        #expect(counts.severe == 2)
        #expect(counts.storm == 2)
        #expect(counts.meso == 2)
        #expect(counts.fire == 2)
    }

    @Test("accepted replacement waits for every map plan before replacing a visible scene")
    func reload_retainsVisibleSceneUntilAllReplacementPlansAreReady() async throws {
        let gate = ReloadGate()
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))
        let center = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let baseline = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([makeFireRisk(level: 5, title: "Elevated Fire Weather Area")])
        )
        let replacement = SelectedFireGatedSpcMapData(gate: gate)

        model.captureInitialCenterCoordinateIfNeeded(center)
        await model.reload(using: baseline, warningSource: warnings, selectedLayer: .fire)
        let reload = Task { await model.reload(using: replacement, warningSource: warnings, selectedLayer: .fire) }

        await gate.waitUntilFirstStormFetchStarts()

        #expect(model.activeScene.legendState.layer == .fire)
        #expect(model.activeScene.legendState.presentationState == .resolving)
        #expect(model.activeScene.legendState.fireItems.map(\.riskLevel) == [5])
        #expect(model.activeScene.canvasState.overlays.first?.key.contains("fire|5|") == true)
        #expect(coordinatesEqual(try #require(model.activeScene.canvasState.initialCenterCoordinate), center))

        model.selectLayer(.categorical)
        #expect(model.activeScene.legendState.layer == .categorical)
        #expect(coordinatesEqual(try #require(model.activeScene.canvasState.initialCenterCoordinate), center))

        await gate.releaseFirstStormFetch()
        await reload.value

        #expect(model.activeScene.legendState.presentationState == .confirmedEmpty)
        #expect(model.activeScene.legendState.layer == .categorical)
        #expect(model.activeScene.canvasState.overlays.isEmpty)
        #expect(coordinatesEqual(try #require(model.activeScene.canvasState.initialCenterCoordinate), center))

        model.selectLayer(.fire)
        #expect(model.activeScene.legendState.fireItems.map(\.riskLevel) == [8])
        #expect(model.activeScene.canvasState.overlays.first?.key.contains("fire|8|") == true)
    }

    @Test("cancelling a staged replacement retains the visible map scene")
    func reload_cancellationRetainsVisibleScene() async throws {
        let gate = ReloadGate()
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))
        let baseline = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([makeFireRisk(level: 5, title: "Elevated Fire Weather Area")])
        )

        await model.reload(using: baseline, warningSource: warnings, selectedLayer: .fire)
        let reload = Task {
            await model.reload(
                using: SelectedFireGatedSpcMapData(gate: gate),
                warningSource: warnings,
                selectedLayer: .fire
            )
        }

        await gate.waitUntilFirstStormFetchStarts()
        reload.cancel()
        await gate.releaseFirstStormFetch()
        await reload.value

        #expect(model.activeScene.legendState.layer == .fire)
        #expect(model.activeScene.legendState.presentationState == .current)
        #expect(model.activeScene.legendState.fireItems.map(\.riskLevel) == [5])
        #expect(model.activeScene.canvasState.overlays.first?.key.contains("fire|5|") == true)
    }

    @Test("failed replacement retains the previous accepted map scene")
    func reload_failureRetainsVisibleScene() async {
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))
        let baseline = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([makeFireRisk(level: 5, title: "Elevated Fire Weather Area")])
        )
        let failedReplacement = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .failure(StubError())
        )

        await model.reload(using: baseline, warningSource: warnings, selectedLayer: .fire)
        await model.reload(using: failedReplacement, warningSource: warnings, selectedLayer: .fire)

        #expect(model.activeScene.legendState.layer == .fire)
        #expect(model.activeScene.legendState.presentationState == .stale)
        #expect(model.activeScene.legendState.fireItems.map(\.riskLevel) == [5])
        #expect(model.activeScene.canvasState.overlays.first?.key.contains("fire|5|") == true)
    }

    @Test("cancelled reload cannot clear a newer scheduled reload")
    func reloadCoordinator_cancelledTaskCannotClearNewerTask() async {
        let gate = IndexedReloadGate()
        let coordinator = MapReloadCoordinator()

        coordinator.schedule { await gate.run(1) }
        await gate.waitUntilStarted(1)
        coordinator.cancel()

        coordinator.schedule { await gate.run(2) }
        await gate.waitUntilStarted(2)
        await gate.release(1)
        await Task.yield()

        #expect(coordinator.hasScheduledReload)
        coordinator.schedule { await gate.run(3) }
        await gate.release(2)
        await gate.waitUntilStarted(3)
        await gate.release(3)
    }

    @Test("reload replaces stale cached layer scenes with the latest map data")
    func reload_replacesStaleCachedScenes() async {
        let store = MutableMapDataStore(
            severeRisks: [],
            stormRisk: [makeStormRisk(level: .slight, title: "SLGT")],
            mesos: [],
            fireRisk: [
                FireRiskDTO(
                    product: "WindRH",
                    issued: now,
                    expires: now.addingTimeInterval(3_600),
                    valid: now,
                    riskLevel: 5,
                    riskLevelDescription: "Elevated",
                    label: "Elevated Fire Weather Area",
                    stroke: nil,
                    fill: nil,
                    polygons: [makeGeoPolygon(title: "Elevated Fire Weather Area")]
                )
            ]
        )
        let service = MutableSpcMapData(store: store)
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        model.selectLayer(.fire)
        #expect(model.activeScene.legendState.fireItems.map(\.riskLevel) == [5])

        await store.replace(
            stormRisk: [makeStormRisk(level: .enhanced, title: "ENH")],
            fireRisk: [
                FireRiskDTO(
                    product: "WindRH",
                    issued: now.addingTimeInterval(600),
                    expires: now.addingTimeInterval(4_200),
                    valid: now,
                    riskLevel: 8,
                    riskLevelDescription: "Critical",
                    label: "Critical Fire Weather Area",
                    stroke: nil,
                    fill: nil,
                    polygons: [makeGeoPolygon(title: "Critical Fire Weather Area")]
                )
            ]
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        #expect(overlayTitles(in: model.activeScene) == ["ENH"])

        model.selectLayer(.fire)
        #expect(model.activeScene.legendState.fireItems.map(\.riskLevel) == [8])
        #expect(model.activeScene.canvasState.overlays.first?.key.contains("fire|8|") == true)
    }

    @Test("reload performs a follow-up fetch when another reload is requested mid-load")
    func reload_performsFollowUpFetchWhenRequestedMidLoad() async {
        let gate = ReloadGate()
        let counter = MapDataCallCounter()
        let service = QueuedReloadSpcMapData(
            gate: gate,
            counter: counter,
            firstStormRisk: [makeStormRisk(level: .slight, title: "SLGT")],
            secondStormRisk: [makeStormRisk(level: .enhanced, title: "ENH")]
        )
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        let firstReload = Task { @MainActor in
            await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        }

        await gate.waitUntilFirstStormFetchStarts()
        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        await gate.releaseFirstStormFetch()
        await firstReload.value

        #expect(overlayTitles(in: model.activeScene) == ["ENH"])

        let counts = await counter.snapshot()
        #expect(counts.storm == 2)
    }

    @Test("initial center coordinate is captured once and preserved across scene changes")
    func initialCenterCoordinate_isCapturedOnce() async throws {
        let model = MapFeatureModel()
        let first = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let second = CLLocationCoordinate2D(latitude: 40.0150, longitude: -105.2705)
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        model.captureInitialCenterCoordinateIfNeeded(first)
        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        model.captureInitialCenterCoordinateIfNeeded(second)

        let stored = try #require(model.initialCenterCoordinate)
        let canvasCoordinate = try #require(model.activeScene.canvasState.initialCenterCoordinate)

        #expect(coordinatesEqual(stored, first))
        #expect(coordinatesEqual(canvasCoordinate, first))
    }

}

private struct SelectedFireGatedSpcMapData: SpcMapData {
    let gate: ReloadGate

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await gate.markFirstStormFetchStarted()
        await gate.waitForRelease()
        return []
    }

    func getMesoMapData() async throws -> [MdDTO] { [] }

    func getFireRisk() async throws -> [FireRiskDTO] {
        [makeFireRisk(level: 8, title: "Critical Fire Weather Area")]
    }
}

private func makeFireRisk(level: Int, title: String) -> FireRiskDTO {
    FireRiskDTO(
        product: "WindRH",
        issued: Date(timeIntervalSince1970: 1_735_689_600),
        expires: Date(timeIntervalSince1970: 1_735_693_200),
        valid: Date(timeIntervalSince1970: 1_735_689_600),
        riskLevel: level,
        riskLevelDescription: level == 8 ? "Critical" : "Elevated",
        label: title,
        stroke: nil,
        fill: nil,
        polygons: [makeGeoPolygon(title: title)]
    )
}


private struct CountingSpcMapData: SpcMapData {
    let counter: MapDataCallCounter
    let severeRisks: [SevereRiskShapeDTO]
    let stormRisk: [StormRiskDTO]
    let mesos: [MdDTO]
    let fireRisk: [FireRiskDTO]

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        await counter.recordSevere()
        return severeRisks
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await counter.recordStorm()
        return stormRisk
    }

    func getMesoMapData() async throws -> [MdDTO] {
        await counter.recordMeso()
        return mesos
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        await counter.recordFire()
        return fireRisk
    }
}

private actor MutableMapDataStore {
    private var severeRisks: [SevereRiskShapeDTO]
    private var stormRisk: [StormRiskDTO]
    private var mesos: [MdDTO]
    private var fireRisk: [FireRiskDTO]

    init(
        severeRisks: [SevereRiskShapeDTO],
        stormRisk: [StormRiskDTO],
        mesos: [MdDTO],
        fireRisk: [FireRiskDTO]
    ) {
        self.severeRisks = severeRisks
        self.stormRisk = stormRisk
        self.mesos = mesos
        self.fireRisk = fireRisk
    }

    func currentSevereRisks() -> [SevereRiskShapeDTO] { severeRisks }
    func currentStormRisk() -> [StormRiskDTO] { stormRisk }
    func currentMesos() -> [MdDTO] { mesos }
    func currentFireRisk() -> [FireRiskDTO] { fireRisk }

    func replace(
        severeRisks: [SevereRiskShapeDTO]? = nil,
        stormRisk: [StormRiskDTO]? = nil,
        mesos: [MdDTO]? = nil,
        fireRisk: [FireRiskDTO]? = nil
    ) {
        if let severeRisks { self.severeRisks = severeRisks }
        if let stormRisk { self.stormRisk = stormRisk }
        if let mesos { self.mesos = mesos }
        if let fireRisk { self.fireRisk = fireRisk }
    }
}

private struct MutableSpcMapData: SpcMapData {
    let store: MutableMapDataStore

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        await store.currentSevereRisks()
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await store.currentStormRisk()
    }

    func getMesoMapData() async throws -> [MdDTO] {
        await store.currentMesos()
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        await store.currentFireRisk()
    }
}
