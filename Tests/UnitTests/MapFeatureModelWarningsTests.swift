import CoreLocation
import Foundation
import ArcusCore
import MapKit
import Testing
@testable import SkyAware

@Suite("MapFeatureModel Warnings")
@MainActor
struct MapFeatureModelWarningsTests {
    private let now = Date(timeIntervalSince1970: 1_735_689_600) // Jan 1, 2025 00:00:00 UTC

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

    @Test("warning geometry toggle hides and restores overlays across thematic layers")
    func warningGeometryToggle_hidesAndRestoresOverlays() async {
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
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([makeWarning(event: "Tornado Warning")])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)
        #expect(overlayKeys(in: model.activeScene).count == 2)

        model.setWarningGeometryVisible(false)
        #expect(overlayKeys(in: model.activeScene).count == 1)
        #expect(overlayKeys(in: model.activeScene).first?.contains("cat|") == true)

        model.selectLayer(.fire)
        #expect(overlayKeys(in: model.activeScene).count == 1)
        #expect(overlayKeys(in: model.activeScene).first?.contains("fire|8|") == true)

        model.setWarningGeometryVisible(true)
        let restoredKeys = overlayKeys(in: model.activeScene)
        #expect(restoredKeys.count == 2)
        #expect(restoredKeys.last?.contains("warn|") == true)
    }

    @Test("warning legend stays hidden when warning geometry is disabled")
    func warningLegend_staysHiddenWhenGeometryIsDisabled() async {
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
        #expect(warningLegendItems(in: model.activeScene).map(\.title) == ["Tornado"])

        model.setWarningGeometryVisible(false)

        #expect(warningLegendItems(in: model.activeScene).isEmpty)
        #expect(model.activeScene.canvasState.overlays.count == 1)
        #expect(model.activeScene.canvasState.overlays.allSatisfy { $0.key.contains("warn|") == false })
    }

    @Test("warning legend stays empty when no warnings are rendered")
    func warningLegend_staysEmptyWhenNoWarningsAreRendered() async {
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

        #expect(warningLegendItems(in: model.activeScene).isEmpty)
    }

    @Test("warning legend renders one tornado row")
    func warningLegend_rendersOneTornadoRow() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([makeWarning(event: "Tornado Warning", id: "warning-1", messageId: "msg-1")])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let items = warningLegendItems(in: model.activeScene)
        #expect(items.map(\.title) == ["Tornado"])
        #expect(items.map(\.accessibilityLabel) == ["Tornado warning"])
    }

    @Test("warning legend renders one severe thunderstorm row")
    func warningLegend_rendersOneSevereThunderstormRow() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Severe Thunderstorm Warning", id: "warning-1", messageId: "msg-1")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let items = warningLegendItems(in: model.activeScene)
        #expect(items.map(\.title) == ["Severe Thunderstorm"])
        #expect(items.map(\.accessibilityLabel) == ["Severe Thunderstorm warning"])
    }

    @Test("warning legend renders one flash flood row")
    func warningLegend_rendersOneFlashFloodRow() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Flash Flood Warning", id: "warning-1", messageId: "msg-1")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let items = warningLegendItems(in: model.activeScene)
        #expect(items.map(\.title) == ["Flash Flood"])
        #expect(items.map(\.accessibilityLabel) == ["Flash Flood warning"])
    }

    @Test("warning legend deduplicates repeated warning types")
    func warningLegend_deduplicatesRepeatedWarningTypes() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Tornado Warning", id: "warning-1", messageId: "msg-1"),
                makeWarning(event: " Tornado Warning ", id: "warning-2", messageId: "msg-2"),
                makeWarning(event: "TORNADO WARNING", id: "warning-3", messageId: "msg-3")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let items = warningLegendItems(in: model.activeScene)
        #expect(items.count == 1)
        #expect(items.map(\.title) == ["Tornado"])
    }

    @Test("warning legend orders mixed warning types deterministically")
    func warningLegend_ordersMixedWarningTypesDeterministically() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Flash Flood Warning", id: "warning-1", messageId: "msg-1"),
                makeWarning(event: "Tornado Warning", id: "warning-2", messageId: "msg-2"),
                makeWarning(event: "Severe Thunderstorm Warning", id: "warning-3", messageId: "msg-3")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let items = warningLegendItems(in: model.activeScene)
        #expect(items.map(\.title) == [
            "Tornado",
            "Severe Thunderstorm",
            "Flash Flood"
        ])
    }

    @Test("warning legend preserves unknown warning events without fabricating a category")
    func warningLegend_preservesUnknownWarningEventsWithoutFabricatingACategory() async {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Special Weather Statement", id: "warning-1", messageId: "msg-1")
            ])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .tornado)

        let items = warningLegendItems(in: model.activeScene)
        #expect(items.map(\.title) == ["Special Weather Statement"])
        #expect(items.map(\.accessibilityLabel) == ["Special Weather Statement"])
    }

    @Test("stale warning scenes keep the rendered warning legend")
    func warningLegend_keepsRenderedWarningsWhenSceneBecomesStale() async {
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
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([
                makeWarning(event: "Tornado Warning", id: "warning-1", messageId: "msg-1")
            ])
        )

        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)
        #expect(warningLegendItems(in: model.activeScene).map(\.title) == ["Tornado"])

        await store.replace(severeRisks: .failure(StubError()))
        await model.reload(using: mapped, warningSource: warnings, selectedLayer: .tornado)

        #expect(model.activeScene.legendState.presentationState == .stale)
        #expect(warningLegendItems(in: model.activeScene).map(\.title) == ["Tornado"])
    }

    @Test("offline cached warning geometry renders from query data and toggle hides and shows it")
    func offlineWarningGeometry_rendersAndToggles() async throws {
        let model = MapFeatureModel()
        let service = StubSpcMapData(
            severeRisks: .success([]),
            stormRisk: .success([]),
            mesos: .success([]),
            fireRisk: .success([])
        )
        let expectedCoordinates = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
            CLLocationCoordinate2D(latitude: 35.2, longitude: -96.7),
            CLLocationCoordinate2D(latitude: 35.3, longitude: -97.2)
        ]
        let warningGeometry: DeviceAlertGeometry = .polygon(
            rings: [[
                DeviceAlertCoordinate(longitude: -97.0, latitude: 35.0),
                DeviceAlertCoordinate(longitude: -96.7, latitude: 35.2),
                DeviceAlertCoordinate(longitude: -97.2, latitude: 35.3)
            ]]
        )
        let warnings = StubArcusAlertQuerying(
            activeWarnings: .success([makeWarning(event: "Tornado Warning", geometry: warningGeometry)])
        )

        await model.reload(using: service, warningSource: warnings, selectedLayer: .categorical)

        let renderedCoordinates = try #require(singleWarningPolygonCoordinates(in: model.activeScene))
        #expect(renderedCoordinates.count == expectedCoordinates.count)
        for (rendered, expected) in zip(renderedCoordinates, expectedCoordinates) {
            #expect(coordinatesEqual(rendered, expected))
        }

        model.setWarningGeometryVisible(false)
        #expect(model.activeScene.canvasState.overlays.isEmpty)

        model.setWarningGeometryVisible(true)
        let restoredCoordinates = try #require(singleWarningPolygonCoordinates(in: model.activeScene))
        #expect(restoredCoordinates.count == expectedCoordinates.count)
        for (restored, expected) in zip(restoredCoordinates, expectedCoordinates) {
            #expect(coordinatesEqual(restored, expected))
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

    private func singleWarningPolygonCoordinates(in scene: MapLayerScene) -> [CLLocationCoordinate2D]? {
        guard scene.canvasState.overlays.count == 1,
              let polygon = scene.canvasState.overlays.first?.overlay as? MKPolygon else {
            return nil
        }

        return polygonCoordinates(of: polygon)
    }

    private func polygonCoordinates(of polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        let points = polygon.points()
        return (0..<polygon.pointCount).map { points[$0].coordinate }
    }
}
