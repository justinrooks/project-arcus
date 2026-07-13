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

    @Test("selectLayer switches to another prepared scene without a reload")
    func selectLayer_switchesToPreparedScene() async {
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
        model.selectLayer(.fire)

        let scene = model.activeScene
        #expect(scene.legendState.layer == .fire)
        #expect(scene.legendState.fireItems.map(\.riskLevel) == [8])
        #expect(scene.canvasState.overlays.count == 1)
        #expect(scene.canvasState.overlays.first?.key.contains("fire|8|") == true)
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
