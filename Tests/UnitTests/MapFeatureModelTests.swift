import CoreLocation
import Foundation
import Testing
@testable import SkyAware

@Suite("MapFeatureModel")
@MainActor
struct MapFeatureModelTests {
    private let now = Date(timeIntervalSince1970: 1_735_689_600) // Jan 1, 2025 00:00:00 UTC

    @Test("reload builds the selected layer scene and shared legend state")
    func reload_buildsSelectedLayerScene() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                SevereRiskShapeDTO(
                    type: .tornado,
                    probabilities: .percent(0.10),
                    stroke: "#654321",
                    fill: "#FEDCBA",
                    polygons: [makeGeoPolygon(title: "10% Tornado Risk")]
                ),
                SevereRiskShapeDTO(
                    type: .tornado,
                    probabilities: .percent(0),
                    stroke: "#654321",
                    fill: "#FEDCBA",
                    polygons: [makeGeoPolygon(title: "CIG Tornado Risk")],
                    label: "CIG1"
                ),
                SevereRiskShapeDTO(
                    type: .hail,
                    probabilities: .percent(0.15),
                    stroke: "#112233",
                    fill: "#332211",
                    polygons: [makeGeoPolygon(title: "15% Hail Risk")]
                )
            ]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let scene = model.activeScene
        #expect(scene.legendState.layer == .tornado)
        #expect(scene.legendState.severeItems.map(\.id) == ["10% Tornado Risk"])
        #expect(scene.legendState.showsHatchingExplanation)
        #expect(scene.canvasState.overlays.count == 2)
        #expect(scene.canvasState.overlays.allSatisfy { $0.key.contains("sev|tornado|") })
        #expect(scene.canvasState.overlayRevision != 0)
    }

    @Test("reload preserves successful layers when one feed fails")
    func reload_preservesPartialResults() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .failure(StubError()),
            stormRisk: .success([makeStormRisk(level: .enhanced, title: "ENH")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)

        let scene = model.activeScene
        #expect(scene.legendState.layer == .categorical)
        #expect(scene.canvasState.overlays.count == 1)
        #expect(scene.canvasState.overlays.first?.key.contains("cat|") == true)
    }

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

    @Test("reload composes warning overlays above the selected thematic layer")
    func reload_composesWarningOverlaysAboveSelectedLayer() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([makeWarning(event: "Tornado Warning")])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)

        let keys = overlayKeys(in: model.activeScene)
        #expect(keys.count == 2)
        #expect(keys.first?.contains("cat|") == true)
        #expect(keys.last?.contains("warn|") == true)
    }

    @Test("reload composes warning overlays for every layer")
    func reload_composesWarningOverlaysForEveryLayer() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                makeSevereRisk(type: .wind, probability: .percent(0.15), title: "15% Wind Risk"),
                makeSevereRisk(type: .hail, probability: .percent(0.15), title: "15% Hail Risk"),
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([
                makeMeso(
                    number: 1,
                    coordinates: [
                        Coordinate2D(latitude: 35.0, longitude: -97.0),
                        Coordinate2D(latitude: 35.2, longitude: -96.8),
                        Coordinate2D(latitude: 35.3, longitude: -97.1)
                    ]
                )
            ]),
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
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([makeWarning(event: "Severe Thunderstorm Warning")])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)

        for layer in MapLayer.allCases {
            model.selectLayer(layer)
            let keys = overlayKeys(in: model.activeScene)
            #expect(keys.last?.contains("warn|") == true)
            #expect(keys.count >= 2)
        }
    }

    @Test("reload keeps thematic layers when the warning query fails")
    func reload_warningQueryFailurePreservesThematicLayers() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([makeStormRisk(level: .enhanced, title: "ENH")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .failure(StubError()))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)

        #expect(overlayTitles(in: model.activeScene) == ["ENH"])
        #expect(model.activeScene.canvasState.overlays.count == 1)
    }

    @Test("reload updates overlay revision when warning geometry changes")
    func reload_warningGeometryChangesUpdateOverlayRevision() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let baselineWarnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(
                    event: "Flash Flood Warning",
                    geometry: .polygon(
                        rings: [[
                            DeviceAlertCoordinate(longitude: -97.0, latitude: 35.0),
                            DeviceAlertCoordinate(longitude: -96.8, latitude: 35.1),
                            DeviceAlertCoordinate(longitude: -97.1, latitude: 35.3)
                        ]]
                    )
                )
            ])
        )
        let revisedWarnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(
                    event: "Flash Flood Warning",
                    geometry: .polygon(
                        rings: [[
                            DeviceAlertCoordinate(longitude: -97.0, latitude: 35.0),
                            DeviceAlertCoordinate(longitude: -96.6, latitude: 35.2),
                            DeviceAlertCoordinate(longitude: -97.2, latitude: 35.4)
                        ]]
                    )
                )
            ])
        )

        await model.reload(using: service, warningSource: baselineWarnings, selectedLayer: .categorical)
        let baselineRevision = model.activeScene.canvasState.overlayRevision
        let baselineKeys = overlayKeys(in: model.activeScene)

        await model.reload(using: service, warningSource: revisedWarnings, selectedLayer: .categorical)
        let revisedRevision = model.activeScene.canvasState.overlayRevision
        let revisedKeys = overlayKeys(in: model.activeScene)

        #expect(baselineRevision != revisedRevision)
        #expect(baselineKeys != revisedKeys)
        #expect(revisedKeys.last?.contains("warn|") == true)
    }

    private func makeStormRisk(level: StormRiskLevel, title: String) -> StormRiskDTO {
        StormRiskDTO(
            riskLevel: level,
            issued: now,
            expires: now.addingTimeInterval(3_600),
            valid: now,
            stroke: nil,
            fill: nil,
            polygons: [makeGeoPolygon(title: title)]
        )
    }

    private func makeSevereRisk(
        type: ThreatType,
        probability: ThreatProbability,
        title: String
    ) -> SevereRiskShapeDTO {
        SevereRiskShapeDTO(
            type: type,
            probabilities: probability,
            stroke: nil,
            fill: nil,
            polygons: [makeGeoPolygon(title: title)]
        )
    }

    private func makeGeoPolygon(
        title: String,
        coordinates: [Coordinate2D] = [
            Coordinate2D(latitude: 35.0, longitude: -97.0),
            Coordinate2D(latitude: 35.1, longitude: -96.9),
            Coordinate2D(latitude: 35.2, longitude: -97.1)
        ]
    ) -> GeoPolygonEntity {
        GeoPolygonEntity(title: title, coordinates: coordinates)
    }

    private func makeMeso(number: Int, coordinates: [Coordinate2D]) -> MdDTO {
        MdDTO(
            number: number,
            title: "SPC MD \(number)",
            link: URL(string: "https://example.com/md/\(number)")!,
            issued: now,
            validStart: now,
            validEnd: now.addingTimeInterval(3_600),
            areasAffected: "Test Area",
            summary: "Test Summary",
            watchProbability: "40",
            threats: nil,
            coordinates: coordinates
        )
    }

    private func makeWarning(
        event: String,
        geometry: DeviceAlertGeometry = .polygon(
            rings: [[
                DeviceAlertCoordinate(longitude: -97.0, latitude: 35.0),
                DeviceAlertCoordinate(longitude: -96.9, latitude: 35.1),
                DeviceAlertCoordinate(longitude: -97.1, latitude: 35.2)
            ]]
        )
    ) -> ActiveWarningGeometry {
        ActiveWarningGeometry(
            id: "warn-1",
            messageId: "msg-1",
            currentRevisionSent: now,
            event: event,
            issued: now,
            effective: now,
            expires: now.addingTimeInterval(3_600),
            ends: now.addingTimeInterval(3_600),
            messageType: "Alert",
            geometry: geometry
        )
    }

    private func coordinatesEqual(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D,
        tolerance: CLLocationDegrees = 0.000_001
    ) -> Bool {
        abs(lhs.latitude - rhs.latitude) <= tolerance &&
        abs(lhs.longitude - rhs.longitude) <= tolerance
    }

    private func overlayTitles(in scene: MapLayerScene) -> [String] {
        scene.canvasState.overlays.compactMap { entry in
            (entry.overlay as? RiskPolygonOverlay)?.polygon.title
        }
    }

    private func overlayKeys(in scene: MapLayerScene) -> [String] {
        scene.canvasState.overlays.map(\.key)
    }
}

private struct StubSpcMapData: SpcMapData {
    let severeRisks: Result<[SevereRiskShapeDTO], Error>
    let stormRisk: Result<[StormRiskDTO], Error>
    let mesos: Result<[MdDTO], Error>
    let fireRisk: Result<[FireRiskDTO], Error>

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try severeRisks.get()
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try stormRisk.get()
    }

    func getMesoMapData() async throws -> [MdDTO] {
        try mesos.get()
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        try fireRisk.get()
    }
}

private struct StubArcusAlertQuerying: ArcusAlertQuerying {
    let activeWarnings: Result<[ActiveWarningGeometry], Error>

    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        []
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        try activeWarnings.get()
    }

    func getWatch(id: String) async throws -> WatchRowDTO? {
        nil
    }
}

private actor MapDataCallCounter {
    private(set) var severe = 0
    private(set) var storm = 0
    private(set) var meso = 0
    private(set) var fire = 0

    func recordSevere() { severe += 1 }
    func recordStorm() { storm += 1 }
    func recordMeso() { meso += 1 }
    func recordFire() { fire += 1 }

    func snapshot() -> (severe: Int, storm: Int, meso: Int, fire: Int) {
        (severe, storm, meso, fire)
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

private actor ReloadGate {
    private var didStartFirstStormFetch = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func markFirstStormFetchStarted() {
        didStartFirstStormFetch = true
        startContinuation?.resume()
        startContinuation = nil
    }

    func waitUntilFirstStormFetchStarts() async {
        guard didStartFirstStormFetch == false else { return }

        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func waitForRelease() async {
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func releaseFirstStormFetch() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private struct QueuedReloadSpcMapData: SpcMapData {
    let gate: ReloadGate
    let counter: MapDataCallCounter
    let firstStormRisk: [StormRiskDTO]
    let secondStormRisk: [StormRiskDTO]

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        await counter.recordSevere()
        return []
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await counter.recordStorm()
        let stormCalls = await counter.snapshot().storm

        if stormCalls == 1 {
            await gate.markFirstStormFetchStarted()
            await gate.waitForRelease()
            return firstStormRisk
        }

        return secondStormRisk
    }

    func getMesoMapData() async throws -> [MdDTO] {
        await counter.recordMeso()
        return []
    }

    func getFireRisk() async throws -> [FireRiskDTO] {
        await counter.recordFire()
        return []
    }
}

private struct StubError: Error {}
