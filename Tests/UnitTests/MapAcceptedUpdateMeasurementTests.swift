import ArcusCore
import Darwin
import Foundation
import MapKit
import XCTest
import Testing
@testable import SkyAware

@MainActor
final class MapAcceptedUpdateMeasurementTests: XCTestCase {
    private static let repetitions = 8

    func testSelectedSceneCriticalPathAfterSourceScoping() async {
        var lines = ["Post-#709 logical coherent publication; in-memory providers; milliseconds"]
        for scenario in ["initial-day1", "initial-day2", "initial-day3", "switch-during-day2-update"] {
            var samples: [Double] = []
            for _ in 0..<Self.repetitions {
                let h = ScopedMapHarness()
                let day: SPCForecastDay = scenario == "initial-day3" ? .day3
                    : scenario == "initial-day1" ? .day1 : .day2
                h.model.selectForecast(day: day, layer: .categorical)
                let start: ContinuousClock.Instant
                if scenario == "switch-during-day2-update" {
                    await h.load()
                    await h.resetCounts()
                    let acceptedPeriod = h.model.activeScene.legendState.forecastPeriod
                    await h.spc.setDay2Revision(1)
                    let gate = IndexedReloadGate()
                    await h.spc.setGate(gate)
                    h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day2", generation: 1))
                    let task = Task { await h.drain() }
                    await gate.waitUntilStarted(1)
                    // Selection can use accepted plans while the replacement source is held.
                    h.model.selectForecast(day: .day3, layer: .categorical)
                    h.model.selectForecast(day: .day2, layer: .wind)
                    h.model.selectForecast(day: .day2, layer: .categorical)
                    XCTAssertEqual(h.model.activeScene.legendState.forecastPeriod, acceptedPeriod)
                    XCTAssertEqual(overlayTitles(in: h.model.activeScene), ["day2-r0"])
                    XCTAssertEqual(h.model.activeScene.legendState.presentationState, .current)
                    let stagedBuilds = await h.planner.snapshot()
                    XCTAssertEqual(stagedBuilds, [:])
                    // Exclude artificial gate dwell; time remaining read/plan/commit work.
                    start = .now
                    await gate.release(1)
                    await task.value
                    samples.append(Self.milliseconds(since: start))
                    XCTAssertEqual(overlayTitles(in: h.model.activeScene), ["day2-r1"])
                    let reads = await h.counts.snapshot()
                    let builds = await h.planner.snapshot()
                    XCTAssertEqual(reads, ["categorical-day2": 1])
                    XCTAssertEqual(builds, [.categorical: 1])
                } else {
                    start = .now
                    await h.load()
                    samples.append(Self.milliseconds(since: start))
                    let reads = await h.counts.snapshot()
                    let builds = await h.planner.snapshot()
                    XCTAssertEqual(reads, ["categorical-current": 1, "severe": 1,
                        "fire": 1, "meso": 1, "warnings": 1, "categorical-day2": 1,
                        "hazards-day2": 1, "categorical-day3": 1])
                    XCTAssertEqual(builds, [.categorical: 3, .wind: 2, .hail: 2,
                        .tornado: 2, .meso: 1, .fire: 1])
                }
                XCTAssertEqual(h.model.activeScene.legendState.forecastDay, day)
                XCTAssertEqual(h.model.activeScene.legendState.presentationState, .current)
                XCTAssertTrue(h.model.activeScene.warningLegendItems.isEmpty)
            }
            lines.append("scenario=\(scenario) repetitions=\(Self.repetitions) " +
                "wallMedianMs=\(Self.median(samples)) wallMeanMs=\(Self.mean(samples)) " +
                "wallStddevMs=\(Self.stddev(samples))")
        }
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "MapSelectedSceneCriticalPath.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAcceptedReloadScenariosRecordSourceReadsAndSelectedSceneChurn() async {
        let counts = MapAcceptedUpdateReadCounts()
        let spc = CountedMapSpcData(counts: counts)
        let meso = CountedMapMesoSource(counts: counts)
        let alerts = CountedMapAlertSource(counts: counts)
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        let model = MapFeatureModel(nowProvider: { now })
        var lines = ["scenario=repetitions sourceReads activeSceneState cacheCapacity=2"]

        let stableWarning = makeWarning(event: "Severe Thunderstorm Warning", id: "warn-warning")
        let scenarios: [(String, String?, SPCForecastDay, [ActiveWarningGeometry])] = [
            ("full-reload", nil, .day1, []),
            ("day1-accepted", "spc.map.convective", .day1, []),
            ("fire-accepted", "spc.map.fire", .day1, []),
            ("day2-hazards-accepted", "spc.map.hazards.day2", .day2, []),
            ("day2-accepted", "spc.map.categorical.day2", .day2,
                [makeWarning(event: "Tornado Warning", id: "warn-day2")]),
            ("day3-accepted", "spc.map.categorical.day3", .day3,
                [makeWarning(event: "Tornado Warning", id: "warn-day3")]),
            ("warning-accepted", "arcus.alerts", .day1, [stableWarning]),
            ("hot-accepted", "home.hot.test", .day1, [stableWarning]),
            ("unchanged-accepted", "spc.map.categorical.day2", .day1, [stableWarning])
        ]

        for (name, feedID, day, warnings) in scenarios {
            model.selectForecast(day: day, layer: .categorical)
            await alerts.setWarnings(warnings)
            if name == "day2-accepted" { await spc.setDay2Revision(1) }
            if name == "day3-accepted" { await spc.setDay3Revision(1) }
            if let feedID {
                XCTAssertTrue(MapFeatureModel.shouldReload(forAcceptedFeedID: feedID))
            }
            var wallMilliseconds: [Double] = []
            var cpuMilliseconds: [Double] = []
            var observedCounts: [String: Int] = [:]
            var selectedOverlayCount = 0
            var selectedOverlayRevision = 0
            var completedReloads = 0

            for generation in 1...Self.repetitions {
                await counts.reset()
                if let feedID {
                    model.invalidateAcceptedInputs(for: .init(feedID: feedID, generation: generation + (name == "unchanged-accepted" ? Self.repetitions : 0)))
                }
                let start = ContinuousClock.now
                var cpuStart = timespec()
                clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpuStart)
                if feedID == nil {
                    await model.reload(using: spc, mesoSource: meso, warningSource: alerts, selectedLayer: .categorical)
                } else {
                    await model.reloadAcceptedInputs(using: spc, mesoSource: meso, warningSource: alerts,
                        selectedLayer: .categorical)
                }
                let elapsed = start.duration(to: .now).components
                wallMilliseconds.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15)
                var cpuEnd = timespec()
                clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpuEnd)
                cpuMilliseconds.append(
                    Double(cpuEnd.tv_sec - cpuStart.tv_sec) * 1_000 +
                        Double(cpuEnd.tv_nsec - cpuStart.tv_nsec) / 1_000_000
                )
                let sampleCounts = await counts.snapshot()
                if observedCounts.isEmpty { observedCounts = sampleCounts }
                XCTAssertEqual(sampleCounts, observedCounts, "Provider reads changed within \(name)")
                selectedOverlayCount = model.activeScene.canvasState.overlays.count
                selectedOverlayRevision = model.activeScene.canvasState.overlayRevision
                XCTAssertEqual(model.activeScene.legendState.forecastDay, day)
                XCTAssertEqual(model.activeScene.legendState.presentationState, .current)
                XCTAssertGreaterThan(selectedOverlayCount, 0)
                completedReloads += 1
            }

            lines.append(
                "MAP_ACCEPTED_UPDATE scenario=\(name) iterations=\(Self.repetitions) " +
                    "reads=\(observedCounts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ",")) " +
                    "completedReloads=\(completedReloads) selectedDay=\(day.rawValue) " +
                    "selectedOverlayCount=\(selectedOverlayCount) " +
                    "selectedOverlayRevision=\(selectedOverlayRevision) " +
                    "wallMedianMs=\(Self.median(wallMilliseconds)) wallMeanMs=\(Self.mean(wallMilliseconds)) " +
                    "wallStddevMs=\(Self.stddev(wallMilliseconds)) " +
                    "cpuMedianMs=\(Self.median(cpuMilliseconds)) cpuMeanMs=\(Self.mean(cpuMilliseconds)) " +
                    "cpuStddevMs=\(Self.stddev(cpuMilliseconds))"
            )
        }

        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "MapAcceptedUpdateMeasurement.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: .now).components
        return Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
    }

    private static func mean(_ samples: [Double]) -> Double {
        samples.reduce(0, +) / Double(samples.count)
    }

    private static func median(_ samples: [Double]) -> Double {
        let sorted = samples.sorted()
        return (sorted[(sorted.count - 1) / 2] + sorted[sorted.count / 2]) / 2
    }

    private static func stddev(_ samples: [Double]) -> Double {
        let average = mean(samples)
        return sqrt(samples.reduce(0) { $0 + pow($1 - average, 2) } / Double(samples.count - 1))
    }
}

private actor MapAcceptedUpdateReadCounts {
    private var values: [String: Int] = [:]

    func record(_ source: String) { values[source, default: 0] += 1 }
    func reset() { values = [:] }
    func snapshot() -> [String: Int] { values }
}

private actor CountedMapSpcData: SpcMapData {
    private let counts: MapAcceptedUpdateReadCounts
    private var day2Revision = 0
    private var day3Revision = 0
    private var currentRevision = 0
    private var richProducts = false
    private var currentFailure = false
    private var emptyCurrent = false
    func setRichProducts() { richProducts = true }
    func setCurrentFailure(_ value: Bool) { currentFailure = value }
    func setEmptyCurrent() { emptyCurrent = true }

    private var periodRevision = 0
    func setPeriodRevision(_ value: Int) { periodRevision = value }
    private var gate: IndexedReloadGate?
    private var gateIndex = 0
    private var failingForecast = false
    private var emptyForecast = false

    func setCurrentRevision(_ revision: Int) { currentRevision = revision }
    func setGate(_ gate: IndexedReloadGate?) { self.gate = gate; gateIndex = 0 }
    func setForecastFailure(_ failing: Bool) { failingForecast = failing }
    func setForecastEmpty(_ empty: Bool) { emptyForecast = empty }


    init(counts: MapAcceptedUpdateReadCounts) { self.counts = counts }

    func setDay2Revision(_ revision: Int) { day2Revision = revision }
    func setDay3Revision(_ revision: Int) { day3Revision = revision }

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        await counts.record("severe")
        if currentFailure { throw StubError() }
        return richProducts ? revisionedHazards() : []
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await counts.record("categorical-current")
        if currentFailure { throw StubError() }
        if emptyCurrent { return [] }
        return [makeStormRisk(level: .slight, title: "current-r\(currentRevision)")]
    }

    func getMesoMapData() async throws -> [MdDTO] { [] }
    func getFireRisk() async throws -> [FireRiskDTO] {
        await counts.record("fire")
        if currentFailure { throw StubError() }
        guard richProducts else { return [] }
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        return [FireRiskDTO(product: "fire", issued: now, expires: now.addingTimeInterval(3600), valid: now,
            riskLevel: currentRevision == 0 ? 5 : 8, riskLevelDescription: "Fire", label: "Fire",
            stroke: nil, fill: nil, polygons: [revisionedPolygon(title: "fire-r\(currentRevision)")])]
    }

    private func revisionedPolygon(title: String) -> GeoPolygonEntity {
        let offset = Double(currentRevision) * 0.2
        return makeGeoPolygon(title: title, coordinates: [
            Coordinate2D(latitude: 35 + offset, longitude: -97),
            Coordinate2D(latitude: 35.2 + offset, longitude: -96.8),
            Coordinate2D(latitude: 35.3 + offset, longitude: -97.1)])
    }

    private func revisionedHazards() -> [SevereRiskShapeDTO] {
        [ThreatType.wind, .hail, .tornado].map { type in
            SevereRiskShapeDTO(type: type, probabilities: .percent(currentRevision == 0 ? 0.05 : 0.15),
                stroke: nil, fill: nil, polygons: [revisionedPolygon(title: "hazard-r\(currentRevision)")])
        }
    }

    func getCategoricalForecast(for day: SPCForecastDay) async throws -> SPCCategoricalForecastSnapshot? {
        await counts.record("categorical-day\(day.rawValue)")
        let revision = day == .day2 ? day2Revision : day == .day3 ? day3Revision : 0
        let original = measurementForecastSnapshot(day: day, revision: revision, empty: emptyForecast)
        let offset = Double(periodRevision) * 60
        let snapshot = SPCCategoricalForecastSnapshot(day: day,
            issued: original.issued.addingTimeInterval(offset), valid: original.valid.addingTimeInterval(offset),
            expires: original.expires.addingTimeInterval(offset), risks: original.risks)
        let failing = failingForecast
        if let gate { gateIndex += 1; await gate.run(gateIndex) }
        if failing { throw StubError() }
        return snapshot
    }

    func getHazardForecast(for day: SPCForecastDay) async throws -> SPCHazardForecastSnapshot? {
        await counts.record("hazards-day\(day.rawValue)")
        guard day == .day2 else { return nil }
        let category = measurementForecastSnapshot(day: day)
        return SPCHazardForecastSnapshot(
            day: day,
            issued: category.issued.addingTimeInterval(-60 + (richProducts ? Double(currentRevision) * 60 : 0)),
            valid: category.valid,
            expires: category.expires,
            shapes: richProducts ? revisionedHazards()
                : [makeSevereRisk(type: .wind, probability: .percent(0.15), title: "Day 2 wind")]
        )
    }
}

private func measurementForecastSnapshot(
    day: SPCForecastDay,
    revision: Int = 0,
    empty: Bool = false
) -> SPCCategoricalForecastSnapshot {
    let issued = Date(timeIntervalSince1970: 1_735_689_600).addingTimeInterval(Double(revision) * 60)
    return SPCCategoricalForecastSnapshot(
        day: day,
        issued: issued,
        valid: issued.addingTimeInterval(Double(day.rawValue) * 86_400),
        expires: issued.addingTimeInterval(4 * 86_400),
        risks: empty ? [] : [makeStormRisk(level: .slight, title: "day\(day.rawValue)-r\(revision)")]
    )
}

private actor CountedMapMesoSource: ArcusMesoQuerying {
    private let counts: MapAcceptedUpdateReadCounts
    private var gate: IndexedReloadGate?
    private var payloads: [MesoscaleDiscussionPayload] = []
    func setGate(_ gate: IndexedReloadGate) { self.gate = gate }
    func setPayloads(_ payloads: [MesoscaleDiscussionPayload]) { self.payloads = payloads }

    init(counts: MapAcceptedUpdateReadCounts) { self.counts = counts }

    func getActiveMesos(h3Cell: Int64?) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]> {
        #expect(h3Cell == nil)
        await counts.record("meso")
        let accepted = payloads
        if let gate { await gate.run(1) }
        return ArcusMesoQueryResponse(value: accepted, source: .live)
    }

    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>? { nil }
}

private actor CountedMapAlertSource: ArcusAlertQuerying {
    private let counts: MapAcceptedUpdateReadCounts
    private var warnings: [ActiveWarningGeometry] = []
    private var fails = false
    func setFailure(_ value: Bool) { fails = value }

    init(counts: MapAcceptedUpdateReadCounts) { self.counts = counts }

    func setWarnings(_ warnings: [ActiveWarningGeometry]) { self.warnings = warnings }
    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] { [] }
    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        await counts.record("warnings")
        if fails { throw StubError() }
        return warnings
    }
    func getAlert(id: String) async throws -> AlertDTO? { nil }
}

@Suite("Scoped Map accepted updates")
@MainActor
struct MapAcceptedUpdateScopeTests {
    @Test("initial load and explicit refresh establish all selectable plans")
    func fullReloadRemainsExplicit() async {
        let h = ScopedMapHarness()
        for _ in 0..<2 {
            await h.resetCounts()
            await h.load()
            #expect(await h.counts.snapshot() == ["categorical-current": 1, "severe": 1, "fire": 1,
                "meso": 1, "warnings": 1, "categorical-day2": 1, "categorical-day3": 1, "hazards-day2": 1])
            #expect(await h.planner.snapshot() == [.categorical: 3, .wind: 2, .hail: 2, .tornado: 2, .meso: 1, .fire: 1])
        }
    }

    @Test("validity-only acceptance updates the legend while reusing identical geometry")
    func validityOnlyUpdatePublishes() async throws {
        let h = ScopedMapHarness()
        await h.load()
        h.model.selectForecast(day: .day2, layer: .categorical)
        let overlay = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        let period = h.model.activeScene.legendState.forecastPeriod
        await h.spc.setPeriodRevision(1)
        await h.accept("spc.map.categorical.day2")
        #expect(h.model.activeScene.legendState.forecastPeriod != period)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === overlay)
    }

    @Test("scoped fire and hazards replace risk geometry and legends without touching another day", arguments: [
        MapForecastSelection(day: .current, layer: .fire),
        MapForecastSelection(day: .day1, layer: .wind), MapForecastSelection(day: .day1, layer: .hail),
        MapForecastSelection(day: .day1, layer: .tornado),
        MapForecastSelection(day: .day2, layer: .wind), MapForecastSelection(day: .day2, layer: .hail),
        MapForecastSelection(day: .day2, layer: .tornado)
    ])
    func scopedRiskReplacement(selection: MapForecastSelection) async throws {
        let h = ScopedMapHarness()
        await h.spc.setRichProducts()
        await h.load()
        h.model.selectForecast(day: .day3, layer: .categorical)
        let untouched = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        h.model.selectForecast(day: selection.day, layer: selection.layer)
        let prior = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        let period = h.model.activeScene.legendState.forecastPeriod
        await h.spc.setCurrentRevision(1)
        let feed = selection.layer == .fire ? "spc.map.fire"
            : selection.day == .day2 ? "spc.map.hazards.day2" : "spc.map.convective"
        await h.accept(feed)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay !== prior)
        #expect(overlayTitles(in: h.model.activeScene) == [selection.layer == .fire ? "fire-r1" : "hazard-r1"])
        if selection.layer == .fire {
            #expect(h.model.activeScene.legendState.fireItems.map(\.riskLevel) == [8])
        } else {
            #expect(h.model.activeScene.legendState.severeItems.map(\.probability) == [.percent(0.15)])
        }
        if selection.day == .day2 { #expect(h.model.activeScene.legendState.forecastPeriod != period) }
        h.model.selectForecast(day: .day3, layer: .categorical)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === untouched)
    }

    @Test("failed scoped thematic reads retain warnings after accepted empty and unavailable plans")
    func failedEmptyThematicReadRetainsWarnings() async throws {
        let h = ScopedMapHarness()
        await h.spc.setEmptyCurrent()
        await h.alerts.setWarnings([makeWarning(event: "Tornado Warning")])
        await h.load()
        #expect(h.model.activeScene.legendState.presentationState == .confirmedEmpty)
        let warning = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        await h.spc.setCurrentFailure(true)
        for generation in 1...2 {
            await h.accept("spc.map.convective", generation: generation)
            #expect(h.model.activeScene.canvasState.overlays.first?.overlay === warning)
            #expect(h.model.activeScene.warningLegendItems.map(\.title) == ["Tornado"])
        }
    }

    @Test("materializer reuses equal overlays and replaces changed signatures or titles")
    func materializerReuseHonorsContent() throws {
        func plan(signature: Int, title: String, offset: Double = 0) -> MapLayerRenderPlan {
            MapLayerRenderPlan(layer: .categorical,
                polygonEntries: [MapPolygonEntry(key: "stable", title: title, subtitle: nil, coordinates: [
                    Coordinate2D(latitude: 35 + offset, longitude: -97),
                    Coordinate2D(latitude: 35.2 + offset, longitude: -96.8),
                    Coordinate2D(latitude: 35.3 + offset, longitude: -97.1)])],
                overlayPlans: [MapOverlayBuildPlan(key: "stable|probability", polygonKey: "stable",
                    kind: .probability, signature: signature)], overlayRevision: signature,
                legendState: .confirmedEmpty(for: .categorical))
        }
        let original = MapSceneMaterializer.materialize(plan: plan(signature: 1, title: "original"),
            initialCenterCoordinate: nil, showsWarningGeometry: true)
        let entry = try #require(original.canvasState.overlays.first)
        let duplicated = MapLayerScene(canvasState: MapCanvasState(overlays: [entry, entry], overlayRevision: 1,
            initialCenterCoordinate: nil), legendState: original.legendState, warningLegendItems: [])
        var constructions = 0
        let equal = MapSceneMaterializer.materialize(plan: plan(signature: 1, title: "original"),
            initialCenterCoordinate: nil, showsWarningGeometry: true, reusing: duplicated,
            makePolygon: { constructions += 1; return $0.polygon })
        #expect(constructions == 0)
        #expect(equal.canvasState.overlayRevision == original.canvasState.overlayRevision)
        #expect(equal.canvasState.overlays.first?.overlay === entry.overlay)
        for changed in [plan(signature: 2, title: "original", offset: 0.2),
                        plan(signature: 1, title: "corrected title")] {
            let scene = MapSceneMaterializer.materialize(plan: changed, initialCenterCoordinate: nil,
                showsWarningGeometry: true, reusing: original,
                makePolygon: { constructions += 1; return $0.polygon })
            #expect(scene.canvasState.overlays.first?.overlay !== entry.overlay)
        }
        #expect(constructions == 2)
    }

    @Test("materialization constructs only changed visible warning geometry and shares thematic polygons")
    func materializationCountsVisibleChanges() throws {
        let mapper = MapPolygonMapper()
        func plan(message: String = "msg-1", hole: Bool = false) -> MapLayerRenderPlan {
            var rings = [[DeviceAlertCoordinate(longitude: -97, latitude: 35),
                DeviceAlertCoordinate(longitude: -96, latitude: 35),
                DeviceAlertCoordinate(longitude: -96, latitude: 36)]]
            if hole {
                rings.append([DeviceAlertCoordinate(longitude: -96.8, latitude: 35.1),
                    DeviceAlertCoordinate(longitude: -96.6, latitude: 35.1),
                    DeviceAlertCoordinate(longitude: -96.6, latitude: 35.2)])
            }
            let warnings = [makeWarning(event: "Tornado Warning", messageId: message,
                geometry: .polygon(rings: rings))]
            let payload = MapDataPayload(stormRisk: .success([makeStormRisk(level: .slight, title: "SLGT")]),
                severeRisks: .success([]), mesos: .success([]), fireRisk: .success([]),
                activeWarnings: .success(warnings))
            let built = MapRenderPlanBuilder.build(layer: .categorical, payload: payload, existingPlan: nil,
                polygonMapper: mapper, warningPolygons: mapper.warningPolygons(from: warnings))
            guard hole, let warning = built.polygonEntries.last, let overlay = built.overlayPlans.last else {
                return built
            }
            // Warning ingestion keeps exterior rings only; exercise interior-capable render inputs directly.
            let entry = MapPolygonEntry(key: warning.key + "|hole", title: warning.title, subtitle: warning.subtitle,
                coordinates: warning.coordinates, interiorCoordinates: [rings[1].map {
                    Coordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }])
            return MapLayerRenderPlan(layer: built.layer,
                polygonEntries: Array(built.polygonEntries.dropLast()) + [entry],
                overlayPlans: Array(built.overlayPlans.dropLast()) + [MapOverlayBuildPlan(
                    key: entry.key + "|warning", polygonKey: entry.key, kind: .warning, signature: overlay.signature + 1)],
                overlayRevision: built.overlayRevision, legendState: built.legendState)
        }
        var constructions = 0
        func render(_ plan: MapLayerRenderPlan, visible: Bool = true, previous: MapLayerScene? = nil) -> MapLayerScene {
            constructions = 0
            return MapSceneMaterializer.materialize(plan: plan, initialCenterCoordinate: nil,
                showsWarningGeometry: visible, reusing: previous,
                makePolygon: { constructions += 1; return $0.polygon })
        }
        let accepted = plan()
        let original = render(accepted)
        #expect(constructions == 2)
        let thematic = try #require(original.canvasState.overlays.first?.overlay)
        let hidden = render(accepted, visible: false)
        #expect(constructions == 1)
        #expect(hidden.warningLegendItems.isEmpty)
        let toggled = render(accepted, visible: false, previous: original)
        #expect(constructions == 0)
        #expect(toggled.canvasState.overlays.first?.overlay === thematic)
        let shown = render(accepted, previous: toggled)
        #expect(constructions == 1)
        #expect(shown.warningLegendItems.map(\.title) == ["Tornado"])
        let stale = render(accepted.withLegendState(accepted.legendState.withPresentationState(.stale)), previous: original)
        #expect(constructions == 0)
        #expect(stale.legendState.presentationState == .stale)
        #expect(stale.canvasState.overlayRevision == original.canvasState.overlayRevision)
        for changed in [plan(message: "msg-2"), plan(hole: true)] {
            let scene = render(changed, previous: original)
            #expect(constructions == 1)
            #expect(scene.canvasState.overlays.first?.overlay === thematic)
            #expect(scene.canvasState.overlays.last?.overlay !== original.canvasState.overlays.last?.overlay)
            #expect(scene.canvasState.overlayRevision != original.canvasState.overlayRevision)
            let warning = try #require(scene.canvasState.overlays.last?.overlay as? MKPolygon)
            #expect(warning.interiorPolygons?.count ?? 0 == (changed.polygonEntries.last?.interiorCoordinates.count ?? 0))
        }
        // Multiple styles for one polygon still construct it just once on a cold scene.
        let first = try #require(accepted.overlayPlans.first)
        let shared = MapLayerRenderPlan(layer: .categorical, polygonEntries: accepted.polygonEntries,
            overlayPlans: [first, MapOverlayBuildPlan(key: first.key + "|intensity", polygonKey: first.polygonKey,
                kind: .intensity(level: 2), signature: first.signature + 1)],
            overlayRevision: 0, legendState: accepted.legendState)
        let scene = render(shared)
        #expect(constructions == 1)
        let probability = try #require(scene.canvasState.overlays.first?.overlay as? RiskPolygonOverlay)
        let intensity = try #require(scene.canvasState.overlays.last?.overlay as? RiskPolygonOverlay)
        #expect(probability.polygon === intensity.polygon)
    }

    @Test("accepted feeds read and plan only their contracted slices", arguments: [
        "spc.map.convective", "spc.map.fire", "spc.map.categorical.day2",
        "spc.map.categorical.day3", "spc.map.hazards.day2", "home.hot.test", "arcus.alert", "arcus.alerts"
    ])
    func feedScopes(feed: String) async throws {
        let h = ScopedMapHarness()
        await h.load()
        await h.resetCounts()
        #expect(h.model.invalidateAcceptedInputs(for: .init(feedID: feed, generation: 1)))
        await h.drain()
        let expected: [String: ([String], [MapLayer])] = [
            "spc.map.convective": (["categorical-current", "severe"], [.categorical, .wind, .hail, .tornado]),
            "spc.map.fire": (["fire"], [.fire]),
            "spc.map.categorical.day2": (["categorical-day2"], [.categorical]),
            "spc.map.categorical.day3": (["categorical-day3"], [.categorical]),
            "spc.map.hazards.day2": (["hazards-day2"], [.wind, .hail, .tornado]),
            "home.hot.test": (["meso", "warnings"], [.meso]),
            "arcus.alert": (["warnings"], []), "arcus.alerts": (["warnings"], [])
        ]
        let (reads, builds) = try #require(expected[feed])
        #expect(await h.counts.snapshot() == Dictionary(uniqueKeysWithValues: reads.map { ($0, 1) }))
        #expect(await h.planner.snapshot() == Dictionary(uniqueKeysWithValues: builds.map { ($0, 1) }))
    }

    @Test("unrelated, duplicate, and unchanged acceptances retain scene and overlay identity")
    func unchangedAcceptancePreservesCache() async throws {
        let h = ScopedMapHarness()
        await h.load()
        let current = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        h.model.selectForecast(day: .day3, layer: .categorical)
        let future = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        await h.resetCounts()
        #expect(!h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.outlook", generation: 100)))
        await h.drain()
        #expect(await h.counts.snapshot().isEmpty)
        #expect(await h.planner.snapshot().isEmpty)
        h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day3", generation: 2))
        let gate = IndexedReloadGate()
        await h.spc.setGate(gate)
        let task = Task { await h.drain() }
        await gate.waitUntilStarted(1)
        #expect(h.model.activeScene.legendState.presentationState == .current)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === future)
        #expect(!h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day3", generation: 2)))
        #expect(!h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day3", generation: 1)))
        await gate.release(1)
        await task.value
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === future)
        h.model.selectForecast(day: .day1, layer: .categorical)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === current)
        h.model.selectForecast(day: .day3, layer: .categorical)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === future)
        #expect(await h.counts.snapshot() == ["categorical-day3": 1])
        await h.resetCounts()
        await h.drain()
        #expect(await h.counts.snapshot().isEmpty)
        #expect(await h.planner.snapshot().isEmpty)
    }

    @Test("warning acceptance preserves thematic overlays, legend, toggles, and future cache")
    func warningSliceIsIndependent() async throws {
        let h = ScopedMapHarness()
        await h.load()
        let thematic = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        h.model.selectForecast(day: .day2, layer: .categorical)
        let future = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        await h.alerts.setWarnings([makeWarning(event: "Tornado Warning")])
        await h.accept("arcus.alert")
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === future)
        #expect(h.model.activeScene.warningLegendItems.isEmpty)
        h.model.selectForecast(day: .day1, layer: .categorical)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === thematic)
        #expect(h.model.activeScene.warningLegendItems.count == 1)
        #expect(h.model.activeScene.legendState.presentationState == .current)
        h.model.setWarningGeometryVisible(false)
        #expect(h.model.activeScene.warningLegendItems.isEmpty)
        await h.alerts.setWarnings([makeWarning(event: "Flash Flood Warning", id: "new")])
        await h.accept("arcus.alerts")
        #expect(h.model.activeScene.warningLegendItems.isEmpty)
        h.model.setWarningGeometryVisible(true)
        #expect(h.model.activeScene.warningLegendItems.map(\.title) == ["Flash Flood"])
        await h.alerts.setFailure(true)
        await h.accept("arcus.alerts", generation: 2)
        #expect(h.model.activeScene.warningLegendItems.map(\.title) == ["Flash Flood"])
        #expect(h.model.activeScene.legendState.presentationState == .current)
        await h.alerts.setFailure(false)
        await h.alerts.setWarnings([])
        await h.accept("arcus.alerts", generation: 3)
        #expect(h.model.activeScene.warningLegendItems.isEmpty)
    }

    @Test("changed, empty, and failed forecasts preserve the exact day and validity")
    func changedEmptyAndFailedForecasts() async throws {
        let h = ScopedMapHarness()
        await h.load()
        h.model.selectForecast(day: .day2, layer: .categorical)
        let original = h.model.activeScene.legendState.forecastPeriod
        await h.spc.setDay2Revision(1)
        await h.accept("spc.map.categorical.day2")
        #expect(overlayTitles(in: h.model.activeScene) == ["day2-r1"])
        #expect(h.model.activeScene.legendState.forecastPeriod != original)
        let accepted = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        let period = h.model.activeScene.legendState.forecastPeriod
        await h.spc.setForecastFailure(true)
        await h.accept("spc.map.categorical.day2", generation: 2)
        #expect(h.model.activeScene.legendState.presentationState == .stale)
        #expect(h.model.activeScene.legendState.forecastPeriod == period)
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === accepted)
        await h.spc.setForecastFailure(false)
        await h.spc.setForecastEmpty(true)
        await h.accept("spc.map.categorical.day2", generation: 3)
        #expect(h.model.activeScene.legendState.presentationState == .confirmedEmpty)
        #expect(h.model.activeScene.canvasState.overlays.isEmpty)
        #expect(h.model.activeScene.legendState.forecastPeriod == period)
    }

    @Test("coordinator merges every pending feed while withholding superseded candidates")
    func coordinatorMergesScopesAndPublishesAtomically() async throws {
        let h = ScopedMapHarness()
        await h.load()
        h.model.selectForecast(day: .day2, layer: .categorical)
        let original = h.model.activeScene.legendState.forecastPeriod
        let gate = IndexedReloadGate()
        await h.spc.setGate(gate)
        await h.spc.setDay2Revision(1)
        await h.resetCounts()
        let coordinator = MapReloadCoordinator()
        let (completions, continuation) = AsyncStream<Void>.makeStream()
        let schedule: (String, Int) -> Void = { feed, generation in
            guard h.model.invalidateAcceptedInputs(for: .init(feedID: feed, generation: generation)) else { return }
            coordinator.schedule { await h.drain(); continuation.yield(()) }
        }
        schedule("spc.map.categorical.day2", 1)
        await gate.waitUntilStarted(1)
        await h.spc.setDay2Revision(2)
        await h.spc.setDay3Revision(1)
        await h.spc.setCurrentRevision(1)
        await h.alerts.setWarnings([makeWarning(event: "Tornado Warning")])
        for feed in ["spc.map.convective", "spc.map.categorical.day2", "spc.map.categorical.day3",
                     "home.hot.test", "arcus.alerts"] {
            schedule(feed, 2)
        }
        h.model.selectForecast(day: .day3, layer: .categorical)
        h.model.selectForecast(day: .day2, layer: .wind)
        h.model.setWarningGeometryVisible(false)
        h.model.setWarningGeometryVisible(true)
        h.model.selectForecast(day: .day2, layer: .categorical)
        await gate.release(1)
        await gate.waitUntilStarted(2)
        #expect(h.model.activeScene.legendState.forecastPeriod == original)
        await gate.release(2)
        await gate.waitUntilStarted(3)
        h.model.selectForecast(day: .day1, layer: .categorical)
        #expect(overlayTitles(in: h.model.activeScene) == ["current-r0"])
        #expect(h.model.activeScene.warningLegendItems.isEmpty)
        h.model.selectForecast(day: .day2, layer: .categorical)
        await gate.release(3)
        var iterator = completions.makeAsyncIterator()
        _ = await iterator.next()
        _ = await iterator.next()
        #expect(overlayTitles(in: h.model.activeScene) == ["day2-r2"])
        h.model.selectForecast(day: .day3, layer: .categorical)
        #expect(overlayTitles(in: h.model.activeScene) == ["day3-r1"])
        h.model.selectForecast(day: .day1, layer: .categorical)
        #expect(overlayTitles(in: h.model.activeScene) == ["current-r1"])
        #expect(h.model.activeScene.warningLegendItems.count == 1)
        #expect(await h.counts.snapshot() == ["categorical-day2": 2, "categorical-day3": 1,
            "categorical-current": 1, "severe": 1, "meso": 1, "warnings": 1])
    }

    @Test("cancelled scoped reads retain accepted content and their pending scope for reentry")
    func cancellationRetainsPendingScope() async throws {
        let h = ScopedMapHarness()
        await h.load()
        h.model.selectForecast(day: .day2, layer: .categorical)
        let original = try #require(h.model.activeScene.canvasState.overlays.first?.overlay)
        let gate = IndexedReloadGate()
        await h.spc.setGate(gate)
        await h.spc.setDay2Revision(1)
        h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day2", generation: 1))
        let task = Task { await h.drain() }
        await gate.waitUntilStarted(1)
        task.cancel()
        await h.spc.setDay3Revision(1)
        h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day3", generation: 1))
        await gate.release(1)
        await task.value
        #expect(h.model.activeScene.canvasState.overlays.first?.overlay === original)
        #expect(h.model.activeScene.legendState.presentationState == .current)
        await h.spc.setGate(nil)
        await h.resetCounts()
        await h.drain()
        #expect(overlayTitles(in: h.model.activeScene) == ["day2-r1"])
        #expect(await h.counts.snapshot() == ["categorical-day2": 1, "categorical-day3": 1])
        h.model.selectForecast(day: .day3, layer: .categorical)
        #expect(overlayTitles(in: h.model.activeScene) == ["day3-r1"])
    }

    @Test("direct in-flight reload requests merge scopes before coherent replacement")
    func directReloadMergesScopes() async {
        let h = ScopedMapHarness()
        await h.load()
        let gate = IndexedReloadGate()
        await h.spc.setGate(gate)
        h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day2", generation: 1))
        let task = Task { await h.drain() }
        await gate.waitUntilStarted(1)
        await h.spc.setDay2Revision(1)
        await h.spc.setDay3Revision(1)
        h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.categorical.day3", generation: 1))
        await h.drain()
        await gate.release(1)
        await gate.waitUntilStarted(2)
        await gate.release(2)
        await gate.waitUntilStarted(3)
        await gate.release(3)
        await task.value
        h.model.selectForecast(day: .day2, layer: .categorical)
        #expect(overlayTitles(in: h.model.activeScene) == ["day2-r1"])
        h.model.selectForecast(day: .day3, layer: .categorical)
        #expect(overlayTitles(in: h.model.activeScene) == ["day3-r1"])
    }

    @Test("unrelated acceptance cannot discard a foreground meso result")
    func foregroundMesoSurvivesUnrelatedAcceptance() async {
        let h = ScopedMapHarness()
        await h.load()
        let gate = IndexedReloadGate()
        await h.meso.setGate(gate)
        await h.meso.setPayloads([makeMesoPayload(number: 709,
            coordinates: [Coordinate2D(latitude: 35, longitude: -97),
                Coordinate2D(latitude: 35.2, longitude: -96.8), Coordinate2D(latitude: 35.3, longitude: -97.1)])])
        let task = Task { await h.model.reloadMesoscale(using: h.meso) }
        await gate.waitUntilStarted(1)
        h.model.invalidateAcceptedInputs(for: .init(feedID: "spc.map.fire", generation: 1))
        await gate.release(1)
        await task.value
        await h.drain()
        h.model.selectLayer(.meso)
        #expect(overlayKeys(in: h.model.activeScene).contains { $0.hasPrefix("meso|709|") })
    }

    @Test("foreground meso refresh reads no SPC or warning source")
    func foregroundMesoIsIndependent() async {
        let h = ScopedMapHarness()
        await h.load()
        await h.resetCounts()
        await h.model.reloadMesoscale(using: h.meso)
        #expect(await h.counts.snapshot() == ["meso": 1])
        #expect(await h.planner.snapshot() == [.meso: 1])
    }
}

@MainActor
private struct ScopedMapHarness {
    let counts = MapAcceptedUpdateReadCounts()
    let planner = CountedMapPlanner()
    let spc: CountedMapSpcData
    let meso: CountedMapMesoSource
    let alerts: CountedMapAlertSource
    let model: MapFeatureModel

    init() {
        spc = CountedMapSpcData(counts: counts)
        meso = CountedMapMesoSource(counts: counts)
        alerts = CountedMapAlertSource(counts: counts)
        model = MapFeatureModel(nowProvider: { Date(timeIntervalSince1970: 1_735_689_600) }, planner: planner)
    }

    func load() async {
        await model.reload(using: spc, mesoSource: meso, warningSource: alerts, selectedLayer: .categorical)
    }

    func drain() async {
        await model.reloadAcceptedInputs(using: spc, mesoSource: meso, warningSource: alerts,
            selectedLayer: model.activeScene.legendState.layer)
    }

    func accept(_ feed: String, generation: Int = 1) async {
        model.invalidateAcceptedInputs(for: .init(feedID: feed, generation: generation))
        await drain()
    }

    func resetCounts() async { await counts.reset(); await planner.reset() }
}

private actor CountedMapPlanner: MapScenePlanning {
    private var builds: [MapLayer: Int] = [:]
    func snapshot() -> [MapLayer: Int] { builds }
    func reset() { builds = [:] }

    func buildRenderPlan(
        for layer: MapLayer, payload: MapDataPayload, existingPlan: MapLayerRenderPlan?,
        polygonMapper: MapPolygonMapper, warningPolygons: KeyedMapPolygons
    ) -> MapLayerRenderPlan {
        builds[layer, default: 0] += 1
        return MapRenderPlanBuilder.build(layer: layer, payload: payload, existingPlan: existingPlan,
            polygonMapper: polygonMapper, warningPolygons: warningPolygons)
    }

    func buildRemainingRenderPlans(
        excluding selectedLayer: MapLayer, payload: MapDataPayload, existingPlans: [MapLayer: MapLayerRenderPlan],
        polygonMapper: MapPolygonMapper, warningPolygons: KeyedMapPolygons
    ) -> [MapLayer: MapLayerRenderPlan] {
        Dictionary(uniqueKeysWithValues: MapLayer.allCases.filter { $0 != selectedLayer }.map { layer in
            (layer, buildRenderPlan(for: layer, payload: payload, existingPlan: existingPlans[layer],
                polygonMapper: polygonMapper, warningPolygons: warningPolygons))
        })
    }
}
