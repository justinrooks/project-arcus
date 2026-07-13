import CoreLocation
import Foundation
import ArcusCore
import MapKit
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

    @Test("active scene starts in loading state before the first reload")
    func activeScene_startsLoadingState() {
        let model = MapFeatureModel()

        #expect(model.activeScene.legendState.presentationState == .loading)
        #expect(model.activeScene.legendState.headlineText == "Getting severe risk…")
        #expect(model.activeScene.legendState.voiceOverText.contains("Loading"))
    }

    @Test("successful polygon response renders the current state")
    func reload_successfulPolygonResponseRendersCurrentState() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                SevereRiskShapeDTO(
                    type: .tornado,
                    probabilities: .percent(0.10),
                    stroke: "#654321",
                    fill: "#FEDCBA",
                    polygons: [makeGeoPolygon(title: "10% Tornado Risk")]
                )
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .current)
        #expect(model.activeScene.legendState.headlineText == "Tornado Risk")
        #expect(model.activeScene.legendState.voiceOverText.contains("loaded"))
        #expect(model.activeScene.canvasState.overlays.count == 1)
    }

    @Test("successful empty response renders the confirmed-empty state")
    func reload_successfulEmptyResponseRendersConfirmedEmptyState() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .confirmedEmpty)
        #expect(model.activeScene.legendState.headlineText == "No tornado risk")
        #expect(model.activeScene.legendState.voiceOverText.contains("confirmed empty"))
        #expect(model.activeScene.canvasState.overlays.isEmpty)
    }

    @Test("failed response without saved data renders unavailable state")
    func reload_failedResponseWithoutSavedDataRendersUnavailableState() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .failure(StubError()),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .unavailable)
        #expect(model.activeScene.legendState.headlineText.contains("unavailable"))
        #expect(model.activeScene.legendState.voiceOverText.contains("No saved"))
    }

    @Test("failed first load keeps active warning overlays when they are available")
    func reload_failedFirstLoad_keepsActiveWarningOverlays() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .failure(StubError()),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Tornado Warning", id: "warning-1", messageId: "msg-1")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .unavailable)
        #expect(model.activeScene.canvasState.overlays.count == 1)
        #expect(overlayKeys(in: model.activeScene).contains { $0.contains("warn|") })
        #expect(warningLegendItems(in: model.activeScene).map(\.title) == ["Tornado"])
    }

    @Test("failed refresh with saved data keeps the rendered scene visible and marks it stale")
    func reload_failedRefreshWithSavedDataKeepsRenderedSceneVisibleAndMarksItStale() async {
        let model = MapFeatureModel()
        let service = MutableResultSpcMapData(
            store: MutableResultMapDataStore(
                severeRisks: .success([
                    makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
                ]),
                stormRisk: .success([]),
                mesos: .success([]),
                fireRisk: .success([])
            )
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)
        await service.store.replace(severeRisks: .failure(StubError()))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .stale)
        #expect(model.activeScene.legendState.headlineText.contains("saved locally"))
        #expect(model.activeScene.legendState.voiceOverText.contains("saved locally"))
        #expect(overlayTitles(in: model.activeScene) == ["10% Tornado Risk"])
    }

    @Test("loading summary identifies the selected layer and loading state")
    func accessibilitySummary_loadingState() {
        let scene = MapLayerScene.placeholder(for: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: scene,
            locationCoordinate: nil,
            showsWarningGeometry: true
        )

        #expect(summary.label == "Map summary")
        #expect(
            summary.value ==
            "Getting tornado risk. Loading. Local relationship unavailable. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("unavailable summary distinguishes missing data without inventing local risk")
    func accessibilitySummary_unavailableState() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .failure(StubError()),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 35.1, longitude: -97.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk unavailable. No saved data. Local relationship unknown. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("stale summary preserves saved-data truthfulness")
    func accessibilitySummary_staleState() async {
        let model = MapFeatureModel()
        let service = MutableResultSpcMapData(
            store: MutableResultMapDataStore(
                severeRisks: .success([
                    makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
                ]),
                stormRisk: .success([]),
                mesos: .success([]),
                fireRisk: .success([])
            )
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)
        await service.store.replace(severeRisks: .failure(StubError()))
        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 35.1, longitude: -97.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk saved locally. Refresh failed. Your location is inside the displayed tornado risk area. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("current summary reports when the user's location intersects the displayed risk")
    func accessibilitySummary_insideDisplayedRisk() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 35.1, longitude: -97.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk loaded. Your location is inside the displayed tornado risk area. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("current summary reports when the user's location is outside the displayed risk")
    func accessibilitySummary_outsideDisplayedRisk() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 40.0, longitude: -100.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk loaded. Your location is outside the displayed tornado risk area. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("summary leaves local relationship explicit when location is unavailable")
    func accessibilitySummary_unknownLocalRelationship() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: nil,
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk loaded. Local relationship unavailable. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("confirmed-empty summary stays truthful without inventing a local comparison")
    func accessibilitySummary_confirmedEmpty() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 35.1, longitude: -97.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "No tornado risk. Successfully loaded and confirmed empty. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("summary describes rendered warning overlays when the warning toggle is on")
    func accessibilitySummary_warningOverlayWithRenderedWarnings() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Tornado Warning", id: "warning-1", messageId: "msg-1")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 35.1, longitude: -97.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk loaded. Your location is inside the displayed tornado risk area. Active warnings overlay on. Displaying tornado warning overlays."
        )
    }

    @Test("summary distinguishes the warning toggle being on without rendered warnings")
    func accessibilitySummary_warningOverlayWithoutRenderedWarnings() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let summary = MapAccessibilitySummary.make(
            scene: model.activeScene,
            locationCoordinate: CLLocationCoordinate2D(latitude: 35.1, longitude: -97.0),
            showsWarningGeometry: true
        )

        #expect(
            summary.value ==
            "Tornado Risk loaded. Your location is inside the displayed tornado risk area. Active warnings overlay on. No active warning areas are displayed."
        )
    }

    @Test("differentiate-without-color styles stay dormant until requested")
    func differentiateWithoutColorStyle_defaultState() {
        let style = MapOverlayDifferentiationStyle.severe(probability: .percent(0.10))

        #expect(style.strokeStyle(differentiateWithoutColor: false) == nil)
        #expect(style.strokeStyle(differentiateWithoutColor: true)?.dashPattern == [6, 4])
    }

    @Test("differentiate-without-color styles provide distinct map patterns")
    func differentiateWithoutColorStyle_enabled() {
        let categorical = MapOverlayDifferentiationStyle.categorical(.enhanced)
        let fire = MapOverlayDifferentiationStyle.fire(riskLevel: 8)
        let meso = MapOverlayDifferentiationStyle.mesoscale

        #expect(categorical.strokeStyle(differentiateWithoutColor: true)?.dashPattern == [10, 4])
        #expect(fire.strokeStyle(differentiateWithoutColor: true)?.dashPattern == [10, 4, 2, 4])
        #expect(meso.strokeStyle(differentiateWithoutColor: true)?.dashPattern == [6, 4])
    }

    @Test("saved offline data remains visible when the layer is revisited")
    func reload_savedOfflineDataRemainsVisibleWhenLayerIsRevisited() async {
        let model = MapFeatureModel()
        let service = MutableResultSpcMapData(
            store: MutableResultMapDataStore(
                severeRisks: .success([
                    makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
                ]),
                stormRisk: .success([]),
                mesos: .success([]),
                fireRisk: .success([
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
                ])
            )
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)
        await service.store.replace(severeRisks: .failure(StubError()))
        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)
        model.selectLayer(.fire)
        model.selectLayer(.tornado)

        #expect(model.activeScene.legendState.presentationState == .stale)
        #expect(overlayTitles(in: model.activeScene) == ["10% Tornado Risk"])
        #expect(model.activeScene.legendState.voiceOverText.contains("saved locally"))
    }

    @Test("refreshing saved data enters resolving state before the new response arrives")
    func reload_refreshingSavedDataEntersResolvingStateBeforeResponse() async {
        let gate = ReloadGate()
        let counter = MapDataCallCounter()
        let firstService = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let gatedService = QueuedReloadSpcMapData(
            gate: gate,
            counter: counter,
            firstStormRisk: [makeStormRisk(level: .slight, title: "SLGT")],
            secondStormRisk: [makeStormRisk(level: .enhanced, title: "ENH")]
        )
        let model = MapFeatureModel()
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: firstService, warningSource: warnings, selectedLayer: .categorical)
        #expect(model.activeScene.legendState.presentationState == .current)

        let secondReload = Task { @MainActor in
            await model.reload(using: gatedService, warningSource: warnings, selectedLayer: .categorical)
        }

        await gate.waitUntilFirstStormFetchStarts()

        #expect(model.activeScene.legendState.presentationState == .resolving)
        #expect(overlayTitles(in: model.activeScene) == ["SLGT"])

        await gate.releaseFirstStormFetch()
        await secondReload.value
    }

    @Test("successful refresh replaces previously stale data")
    func reload_successfulRefreshReplacesPreviouslyStaleData() async {
        let model = MapFeatureModel()
        let store = MutableResultMapDataStore(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let mapped = MutableResultSpcMapData(store: store)
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)
        await store.replace(severeRisks: .failure(StubError()))
        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)
        #expect(model.activeScene.legendState.presentationState == .stale)

        await store.replace(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.15), title: "15% Tornado Risk")
            ])
        )
        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .current)
        #expect(model.activeScene.legendState.headlineText == "Tornado Risk")
        #expect(overlayTitles(in: model.activeScene) == ["15% Tornado Risk"])
    }

    @Test("failed refresh preserves the previously rendered overlays")
    func reload_failedRefreshPreservesPreviouslyRenderedOverlays() async {
        let model = MapFeatureModel()
        let store = MutableResultMapDataStore(
            severeRisks: .success([
                makeSevereRisk(type: .tornado, probability: .percent(0.10), title: "10% Tornado Risk")
            ]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let mapped = MutableResultSpcMapData(store: store)
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)
        let baselineOverlays = overlayTitles(in: model.activeScene)

        await store.replace(severeRisks: .failure(StubError()))
        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .stale)
        #expect(overlayTitles(in: model.activeScene) == baselineOverlays)
    }

    @Test("switching between layers preserves independent availability states")
    func layerSelection_preservesIndependentAvailabilityStates() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .failure(StubError()),
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
                    stroke: nil,
                    fill: nil,
                    polygons: [makeGeoPolygon(title: "Critical Fire Weather Area")]
                )
            ])
        )
        let warnings = StubArcusAlertQuerying(activeWarnings: .success([]))

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        #expect(model.activeScene.legendState.presentationState == .current)

        model.selectLayer(.fire)
        #expect(model.activeScene.legendState.presentationState == .current)
        #expect(model.activeScene.legendState.headlineText == "Fire Risk")

        model.selectLayer(.tornado)
        #expect(model.activeScene.legendState.presentationState == .unavailable)
        #expect(model.activeScene.legendState.voiceOverText.contains("No saved"))

        model.selectLayer(.categorical)
        #expect(model.activeScene.legendState.presentationState == .current)
        #expect(model.activeScene.legendState.headlineText == "Severe Risk")
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
}
