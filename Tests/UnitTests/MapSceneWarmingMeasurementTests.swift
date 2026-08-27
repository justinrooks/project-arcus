import ArcusCore
import Darwin
import Foundation
import MapKit
import XCTest
@testable import SkyAware

@MainActor
final class MapSceneWarmingMeasurementTests: XCTestCase {
    private static let selectedLayer = MapLayer.categorical
    private static let firstSwitchLayer = MapLayer.wind
    private static let measuredIterations = 10

    func testInactiveSceneWarmingTradeoff() {
        let fixtures = MapSceneMeasurementFixture.all

        for fixture in fixtures {
            verifyDeterminism(of: fixture)
            _ = measureIteration(fixture: fixture, showsWarningGeometry: false)
            _ = measureIteration(fixture: fixture, showsWarningGeometry: true)
        }

        var accumulator = MapSceneMeasurementAccumulator()
        for _ in 0..<Self.measuredIterations {
            for fixture in fixtures {
                accumulator.record(
                    measureIteration(fixture: fixture, showsWarningGeometry: false),
                    file: #filePath,
                    line: #line
                )
                accumulator.record(
                    measureIteration(fixture: fixture, showsWarningGeometry: true),
                    file: #filePath,
                    line: #line
                )
            }
        }

        let options = XCTMeasureOptions.default
        options.iterationCount = Self.measuredIterations

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()], options: options) {
            for fixture in fixtures {
                _ = measureIteration(fixture: fixture, showsWarningGeometry: false)
                _ = measureIteration(fixture: fixture, showsWarningGeometry: true)
            }
        }

        XCTAssertEqual(accumulator.iterationCounts, [Self.measuredIterations])

        let attachment = XCTAttachment(
            string: accumulator.report(fixtures: fixtures, measuredIterations: Self.measuredIterations)
        )
        attachment.name = "MapSceneWarmingMeasurement.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func verifyDeterminism(of fixture: MapSceneMeasurementFixture) {
        for layer in MapLayer.allCases {
            guard let plan = fixture.plans[layer] else {
                XCTFail("Missing \(fixture.profile.name) render plan for \(layer.rawValue)")
                continue
            }

            for showsWarningGeometry in [false, true] {
                let first = materialize(plan: plan, showsWarningGeometry: showsWarningGeometry)
                let second = materialize(plan: plan, showsWarningGeometry: showsWarningGeometry)
                let expectedWarnings = showsWarningGeometry ? fixture.profile.warningCount : 0
                let expectedOverlays = fixture.profile.riskCount(for: layer) + expectedWarnings

                XCTAssertEqual(first.canvasState.overlays.count, expectedOverlays)
                XCTAssertEqual(first.canvasState.overlays.map(\.key), second.canvasState.overlays.map(\.key))
                XCTAssertEqual(first.canvasState.overlayRevision, second.canvasState.overlayRevision)
                XCTAssertEqual(
                    first.warningLegendItems.count,
                    showsWarningGeometry ? min(fixture.profile.warningCount, 3) : 0
                )
            }

            verifyProductionShape(of: plan, fixture: fixture)
        }
    }

    private func verifyProductionShape(
        of plan: MapLayerRenderPlan,
        fixture: MapSceneMeasurementFixture
    ) {
        let riskCount = fixture.profile.riskCount(for: plan.layer)
        let riskEntries = Array(plan.polygonEntries.prefix(riskCount))
        let riskPlans = Array(plan.overlayPlans.prefix(riskCount))

        XCTAssertEqual(riskEntries.count, riskCount)
        XCTAssertEqual(riskPlans.count, riskCount)

        for (entry, overlayPlan) in zip(riskEntries, riskPlans) {
            XCTAssertEqual(overlayPlan.polygonKey, entry.key)

            switch plan.layer {
            case .categorical:
                XCTAssertTrue(entry.key.hasPrefix("cat|"))
                XCTAssertNotNil(StormRiskPolygonStyleMetadata.decode(from: entry.subtitle))
            case .wind, .hail, .tornado:
                XCTAssertTrue(entry.key.hasPrefix("sev|\(plan.layer.rawValue)|"))
                XCTAssertNotNil(RiskPolygonStyleResolver.parseRiskLabel(entry.title ?? ""))
                XCTAssertNotNil(StormRiskPolygonStyleMetadata.decode(from: entry.subtitle))
            case .meso:
                XCTAssertTrue(entry.key.hasPrefix("meso|"))
                XCTAssertEqual(entry.title, MapLayer.meso.key)
                XCTAssertNil(entry.subtitle)
            case .fire:
                XCTAssertTrue(entry.key.hasPrefix("fire|"))
                XCTAssertNotNil(RiskPolygonStyleResolver.parseRiskLabel(entry.title ?? ""))
                XCTAssertNotNil(StormRiskPolygonStyleMetadata.decode(from: entry.subtitle))
            }

            switch overlayPlan.kind {
            case .probability:
                XCTAssertTrue(overlayPlan.key.hasSuffix("|probability"))
            case .intensity(let level):
                XCTAssertTrue([MapLayer.wind, .hail, .tornado].contains(plan.layer))
                XCTAssertEqual(
                    StormRiskPolygonStyleMetadata.decode(from: entry.subtitle)?.cigLevel,
                    level
                )
                XCTAssertTrue(overlayPlan.key.hasSuffix("|intensity|\(level)"))
            case .warning:
                XCTFail("Risk entry unexpectedly used warning overlay kind")
            }
        }

        for (entry, overlayPlan) in zip(
            plan.polygonEntries.dropFirst(riskCount),
            plan.overlayPlans.dropFirst(riskCount)
        ) {
            XCTAssertTrue(entry.key.hasPrefix("warn|"))
            XCTAssertEqual(overlayPlan.key, "\(entry.key)|warning")
            if case .warning = overlayPlan.kind {
                continue
            }
            XCTFail("Warning entry did not use warning overlay kind")
        }
    }

    private func measureIteration(
        fixture: MapSceneMeasurementFixture,
        showsWarningGeometry: Bool
    ) -> [MapSceneMeasurementObservation] {
        var observations: [MapSceneMeasurementObservation] = []
        let inactiveLayers = MapLayer.allCases.filter { $0 != Self.selectedLayer }

        let selected = timed {
            materialize(
                plan: fixture.plan(for: Self.selectedLayer),
                showsWarningGeometry: showsWarningGeometry
            )
        }
        observations.append(
            observation(
                fixture: fixture,
                showsWarningGeometry: showsWarningGeometry,
                scenario: "selected",
                timing: selected.timing,
                cachedScenes: [Self.selectedLayer: selected.value]
            )
        )

        for layer in inactiveLayers {
            let inactive = timed {
                materialize(plan: fixture.plan(for: layer), showsWarningGeometry: showsWarningGeometry)
            }
            observations.append(
                observation(
                    fixture: fixture,
                    showsWarningGeometry: showsWarningGeometry,
                    scenario: "inactive-\(layer.rawValue)",
                    timing: inactive.timing,
                    cachedScenes: [layer: inactive.value]
                )
            )
        }

        let inactiveTotal = timed {
            Dictionary(uniqueKeysWithValues: inactiveLayers.map { layer in
                (
                    layer,
                    materialize(plan: fixture.plan(for: layer), showsWarningGeometry: showsWarningGeometry)
                )
            })
        }
        observations.append(
            observation(
                fixture: fixture,
                showsWarningGeometry: showsWarningGeometry,
                scenario: "inactive-total",
                timing: inactiveTotal.timing,
                cachedScenes: inactiveTotal.value
            )
        )

        let eager = timed {
            Dictionary(uniqueKeysWithValues: MapLayer.allCases.map { layer in
                (
                    layer,
                    materialize(plan: fixture.plan(for: layer), showsWarningGeometry: showsWarningGeometry)
                )
            })
        }
        observations.append(
            observation(
                fixture: fixture,
                showsWarningGeometry: showsWarningGeometry,
                scenario: "selected-plus-eager",
                timing: eager.timing,
                cachedScenes: eager.value
            )
        )

        let selectedThenCold = timed {
            var cache = MapSceneCache()
            cache.insert(
                materialize(
                    plan: fixture.plan(for: Self.selectedLayer),
                    showsWarningGeometry: showsWarningGeometry
                ),
                for: Self.selectedLayer
            )
            cache.insert(
                materialize(
                    plan: fixture.plan(for: Self.firstSwitchLayer),
                    showsWarningGeometry: showsWarningGeometry
                ),
                for: Self.firstSwitchLayer
            )
            return cache
        }
        observations.append(
            observation(
                fixture: fixture,
                showsWarningGeometry: showsWarningGeometry,
                scenario: "selected-plus-first-cold-switch",
                timing: selectedThenCold.timing,
                cache: selectedThenCold.value
            )
        )

        var coldCache = MapSceneCache()
        coldCache.insert(selected.value, for: Self.selectedLayer)
        let coldSwitch = timed {
            let scene = materialize(
                plan: fixture.plan(for: Self.firstSwitchLayer),
                showsWarningGeometry: showsWarningGeometry
            )
            coldCache.insert(scene, for: Self.firstSwitchLayer)
            return scene
        }
        observations.append(
            observation(
                fixture: fixture,
                showsWarningGeometry: showsWarningGeometry,
                scenario: "first-cold-switch",
                timing: coldSwitch.timing,
                cache: coldCache
            )
        )

        let warmSwitch = timed { coldCache.scene(for: Self.firstSwitchLayer) }
        XCTAssertNotNil(warmSwitch.value)
        observations.append(
            observation(
                fixture: fixture,
                showsWarningGeometry: showsWarningGeometry,
                scenario: "first-warm-switch",
                timing: warmSwitch.timing,
                cache: coldCache
            )
        )

        return observations
    }

    private func materialize(
        plan: MapLayerRenderPlan,
        showsWarningGeometry: Bool
    ) -> MapLayerScene {
        MapSceneMaterializer.materialize(
            plan: plan,
            initialCenterCoordinate: nil,
            showsWarningGeometry: showsWarningGeometry
        )
    }

    private func observation(
        fixture: MapSceneMeasurementFixture,
        showsWarningGeometry: Bool,
        scenario: String,
        timing: MapSceneMeasurementTiming,
        cachedScenes: [MapLayer: MapLayerScene]
    ) -> MapSceneMeasurementObservation {
        MapSceneMeasurementObservation(
            fixture: fixture.profile.name,
            warnings: showsWarningGeometry ? "on" : "off",
            scenario: scenario,
            timing: timing,
            cachedSceneCount: cachedScenes.count,
            cachedOverlayCount: cachedScenes.values.reduce(0) { $0 + $1.canvasState.overlays.count }
        )
    }

    private func observation(
        fixture: MapSceneMeasurementFixture,
        showsWarningGeometry: Bool,
        scenario: String,
        timing: MapSceneMeasurementTiming,
        cache: MapSceneCache
    ) -> MapSceneMeasurementObservation {
        MapSceneMeasurementObservation(
            fixture: fixture.profile.name,
            warnings: showsWarningGeometry ? "on" : "off",
            scenario: scenario,
            timing: timing,
            cachedSceneCount: cache.retainedSceneCount,
            cachedOverlayCount: cache.retainedOverlayCount
        )
    }

    private func timed<Value>(_ operation: () -> Value) -> (value: Value, timing: MapSceneMeasurementTiming) {
        let wallStart = DispatchTime.now().uptimeNanoseconds
        let cpuStart = processCPUTimeNanoseconds()
        let value = operation()
        let cpuEnd = processCPUTimeNanoseconds()
        let wallEnd = DispatchTime.now().uptimeNanoseconds

        return (
            value,
            MapSceneMeasurementTiming(
                wallMilliseconds: Double(wallEnd - wallStart) / 1_000_000,
                cpuMilliseconds: Double(cpuEnd - cpuStart) / 1_000_000
            )
        )
    }

    private func processCPUTimeNanoseconds() -> UInt64 {
        var value = timespec()
        guard clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value) == 0 else { return 0 }
        return UInt64(value.tv_sec) * 1_000_000_000 + UInt64(value.tv_nsec)
    }
}

private struct MapSceneMeasurementFixture {
    let profile: MapSceneMeasurementProfile
    let plans: [MapLayer: MapLayerRenderPlan]

    static var all: [MapSceneMeasurementFixture] {
        MapSceneMeasurementProfile.all.map { profile in
            MapSceneMeasurementFixture(
                profile: profile,
                plans: Dictionary(uniqueKeysWithValues: MapLayer.allCases.enumerated().map { layerIndex, layer in
                    (layer, makePlan(profile: profile, layer: layer, layerIndex: layerIndex))
                })
            )
        }
    }

    func plan(for layer: MapLayer) -> MapLayerRenderPlan {
        guard let plan = plans[layer] else {
            preconditionFailure("Missing \(profile.name) render plan for \(layer.rawValue)")
        }
        return plan
    }

    private static func makePlan(
        profile: MapSceneMeasurementProfile,
        layer: MapLayer,
        layerIndex: Int
    ) -> MapLayerRenderPlan {
        var polygonEntries: [MapPolygonEntry] = []
        var overlayPlans: [MapOverlayBuildPlan] = []

        for index in 0..<profile.riskCount(for: layer) {
            let shape = productionShape(
                profile: profile,
                layer: layer,
                index: index
            )
            polygonEntries.append(
                polygonEntry(
                    key: shape.key,
                    title: shape.title,
                    subtitle: shape.subtitle,
                    seed: layerIndex * 10_000 + index,
                    vertexCount: profile.vertexCount,
                    includesHole: profile.holeInterval.map { index.isMultiple(of: $0) } ?? false
                )
            )
            let overlayKey = overlayKey(for: shape.key, kind: shape.kind)
            overlayPlans.append(
                MapOverlayBuildPlan(
                    key: overlayKey,
                    polygonKey: shape.key,
                    kind: shape.kind,
                    signature: overlaySignature(
                        key: overlayKey,
                        subtitle: shape.subtitle,
                        kind: shape.kind
                    )
                )
            )
        }

        let warningEvents = ["Tornado Warning", "Severe Thunderstorm Warning", "Flash Flood Warning"]
        for index in 0..<profile.warningCount {
            let eventKey = warningEvents[index % warningEvents.count].replacingOccurrences(of: " ", with: "_")
            let polygonKey = "warn|fixture-\(profile.name)-\(index)|rev-fixture-\(index)|\(eventKey)|0|fixture-\(index)"
            polygonEntries.append(
                polygonEntry(
                    key: polygonKey,
                    title: warningEvents[index % warningEvents.count],
                    subtitle: nil,
                    seed: 100_000 + index,
                    vertexCount: profile.vertexCount,
                    includesHole: false
                )
            )
            let overlayKey = "\(polygonKey)|warning"
            overlayPlans.append(
                MapOverlayBuildPlan(
                    key: overlayKey,
                    polygonKey: polygonKey,
                    kind: .warning,
                    signature: overlaySignature(
                        key: overlayKey,
                        subtitle: nil,
                        kind: .warning
                    )
                )
            )
        }

        return MapLayerRenderPlan(
            layer: layer,
            polygonEntries: polygonEntries,
            overlayPlans: overlayPlans,
            overlayRevision: 0,
            legendState: .current(
                for: layer,
                severeItems: [],
                fireItems: [],
                showsHatchingExplanation: false
            )
        )
    }

    private static func polygonEntry(
        key: String,
        title: String,
        subtitle: String?,
        seed: Int,
        vertexCount: Int,
        includesHole: Bool
    ) -> MapPolygonEntry {
        let row = seed / 100
        let column = seed % 100
        let latitude = 24.5 + Double(row % 250) * 0.08
        let longitude = -124.0 + Double(column) * 0.25
        let radius = 0.035 + Double(seed % 5) * 0.003
        let coordinates = ring(
            centerLatitude: latitude,
            centerLongitude: longitude,
            radius: radius,
            vertexCount: vertexCount
        )
        let holes = includesHole ? [
            ring(
                centerLatitude: latitude,
                centerLongitude: longitude,
                radius: radius * 0.3,
                vertexCount: max(4, vertexCount / 3)
            )
        ] : []

        return MapPolygonEntry(
            key: key,
            title: title,
            subtitle: subtitle,
            coordinates: coordinates,
            interiorCoordinates: holes
        )
    }

    private static func productionShape(
        profile: MapSceneMeasurementProfile,
        layer: MapLayer,
        index: Int
    ) -> MapSceneMeasurementProductionShape {
        let fingerprint = "fixture-\(profile.name)-\(layer.rawValue)-\(index)"
        let fillHex = ["#66C7E9FF", "#66FFD966", "#66FFB347", "#66FF6961"][index % 4]
        let strokeHex = ["#247BA0", "#A67C00", "#C65D00", "#B22222"][index % 4]

        switch layer {
        case .categorical:
            let levels = [
                (key: "tstm", title: "General Thunderstorms"),
                (key: "mrgl", title: "Marginal Risk"),
                (key: "slgt", title: "Slight Risk"),
                (key: "enh", title: "Enhanced Risk"),
                (key: "mdt", title: "Moderate Risk"),
                (key: "high", title: "High Risk")
            ]
            let level = levels[index % levels.count]
            return MapSceneMeasurementProductionShape(
                key: "cat|\(level.key)|1735689600|\(fingerprint)",
                title: level.title,
                subtitle: StormRiskPolygonStyleMetadata(fillHex: fillHex, strokeHex: strokeHex).encoded,
                kind: .probability
            )

        case .wind, .hail, .tornado:
            let percentages = [5, 10, 15, 30, 45, 60]
            let percentage = percentages[index % percentages.count]
            let isIntensity = index.isMultiple(of: 7)
            let intensityLevel = isIntensity ? (index % 3) + 1 : nil
            let label = intensityLevel.map { "CIG\($0)" } ?? "\(percentage)%"
            return MapSceneMeasurementProductionShape(
                key: "sev|\(layer.rawValue)|p\(percentage)|\(label)|\(fingerprint)",
                title: "\(percentage)% \(layer.title) Risk",
                subtitle: StormRiskPolygonStyleMetadata(
                    fillHex: fillHex,
                    strokeHex: strokeHex,
                    cigLevel: intensityLevel
                ).encoded,
                kind: intensityLevel.map { .intensity(level: $0) } ?? .probability
            )

        case .meso:
            return MapSceneMeasurementProductionShape(
                key: "meso|\(1_000 + index)|\(fingerprint)",
                title: MapLayer.meso.key,
                subtitle: nil,
                kind: .probability
            )

        case .fire:
            let levels = [
                (risk: 5, title: "Elevated Fire Weather Area"),
                (risk: 8, title: "Critical Fire Weather Area"),
                (risk: 10, title: "Extremely Critical Fire Weather Area")
            ]
            let level = levels[index % levels.count]
            return MapSceneMeasurementProductionShape(
                key: "fire|\(level.risk)|1735689600|\(fingerprint)",
                title: level.title,
                subtitle: StormRiskPolygonStyleMetadata(fillHex: fillHex, strokeHex: strokeHex).encoded,
                kind: .probability
            )
        }
    }

    private static func overlayKey(
        for polygonKey: String,
        kind: MapOverlayBuildPlan.Kind
    ) -> String {
        switch kind {
        case .probability:
            return "\(polygonKey)|probability"
        case .intensity(let level):
            return "\(polygonKey)|intensity|\(level)"
        case .warning:
            return "\(polygonKey)|warning"
        }
    }

    private static func overlaySignature(
        key: String,
        subtitle: String?,
        kind: MapOverlayBuildPlan.Kind
    ) -> Int {
        var hasher = StableMapHasher()
        hasher.combine(key)
        hasher.combine(subtitle)

        switch kind {
        case .probability:
            hasher.combine("probability")
        case .intensity(let level):
            hasher.combine("intensity")
            hasher.combine(level)
        case .warning:
            hasher.combine("warning")
        }

        return hasher.intValue
    }

    private static func ring(
        centerLatitude: Double,
        centerLongitude: Double,
        radius: Double,
        vertexCount: Int
    ) -> [Coordinate2D] {
        (0..<vertexCount).map { index in
            let angle = Double(index) * 2 * .pi / Double(vertexCount)
            return Coordinate2D(
                latitude: centerLatitude + sin(angle) * radius,
                longitude: centerLongitude + cos(angle) * radius
            )
        }
    }
}

private struct MapSceneMeasurementProductionShape {
    let key: String
    let title: String
    let subtitle: String?
    let kind: MapOverlayBuildPlan.Kind
}

private struct MapSceneMeasurementProfile {
    let name: String
    let riskCounts: [MapLayer: Int]
    let warningCount: Int
    let vertexCount: Int
    let holeInterval: Int?

    static let all = [
        MapSceneMeasurementProfile(
            name: "small",
            riskCounts: [.categorical: 1, .wind: 1, .hail: 1, .tornado: 1, .meso: 1, .fire: 1],
            warningCount: 1,
            vertexCount: 4,
            holeInterval: nil
        ),
        MapSceneMeasurementProfile(
            name: "representative",
            riskCounts: [.categorical: 5, .wind: 8, .hail: 8, .tornado: 6, .meso: 3, .fire: 4],
            warningCount: 4,
            vertexCount: 12,
            holeInterval: 3
        ),
        MapSceneMeasurementProfile(
            name: "high-volume",
            riskCounts: [.categorical: 80, .wind: 120, .hail: 120, .tornado: 80, .meso: 40, .fire: 60],
            warningCount: 25,
            vertexCount: 48,
            holeInterval: 4
        )
    ]

    func riskCount(for layer: MapLayer) -> Int {
        riskCounts[layer, default: 0]
    }

    var description: String {
        let counts = MapLayer.allCases.map { "\($0.rawValue):\(riskCount(for: $0))" }.joined(separator: ",")
        let holeIntervalDescription = holeInterval.map(String.init) ?? "none"
        return "fixture=\(name) riskCounts=[\(counts)] warningsPerScene=\(warningCount) " +
            "verticesPerExterior=\(vertexCount) holeInterval=\(holeIntervalDescription)"
    }
}

private struct MapSceneMeasurementTiming {
    let wallMilliseconds: Double
    let cpuMilliseconds: Double
}

private struct MapSceneMeasurementObservation {
    let fixture: String
    let warnings: String
    let scenario: String
    let timing: MapSceneMeasurementTiming
    let cachedSceneCount: Int
    let cachedOverlayCount: Int

    var key: String { "\(fixture)|\(warnings)|\(scenario)" }
}

private struct MapSceneMeasurementSeries {
    let fixture: String
    let warnings: String
    let scenario: String
    let cachedSceneCount: Int
    let cachedOverlayCount: Int
    var wallSamples: [Double]
    var cpuSamples: [Double]
}

private struct MapSceneMeasurementAccumulator {
    private var seriesByKey: [String: MapSceneMeasurementSeries] = [:]

    var iterationCounts: Set<Int> {
        Set(seriesByKey.values.map(\.wallSamples.count))
    }

    mutating func record(
        _ observations: [MapSceneMeasurementObservation],
        file: StaticString,
        line: UInt
    ) {
        for observation in observations {
            if var existing = seriesByKey[observation.key] {
                XCTAssertEqual(existing.cachedSceneCount, observation.cachedSceneCount, file: file, line: line)
                XCTAssertEqual(existing.cachedOverlayCount, observation.cachedOverlayCount, file: file, line: line)
                existing.wallSamples.append(observation.timing.wallMilliseconds)
                existing.cpuSamples.append(observation.timing.cpuMilliseconds)
                seriesByKey[observation.key] = existing
            } else {
                seriesByKey[observation.key] = MapSceneMeasurementSeries(
                    fixture: observation.fixture,
                    warnings: observation.warnings,
                    scenario: observation.scenario,
                    cachedSceneCount: observation.cachedSceneCount,
                    cachedOverlayCount: observation.cachedOverlayCount,
                    wallSamples: [observation.timing.wallMilliseconds],
                    cpuSamples: [observation.timing.cpuMilliseconds]
                )
            }
        }
    }

    func report(
        fixtures: [MapSceneMeasurementFixture],
        measuredIterations: Int
    ) -> String {
        let environment = ProcessInfo.processInfo.environment
        let sourceIdentity = environment["MAP_SCENE_MEASUREMENT_SOURCE"] ?? "working-tree-test-binary"
        let simulator = environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown"
        let runtime = environment["SIMULATOR_RUNTIME_VERSION"] ?? ProcessInfo.processInfo.operatingSystemVersionString
        let capturedSamples = iterationCounts.first ?? 0
        var lines = [
            "MAP_SCENE_WARMING sourceIdentity=\(sourceIdentity) simulator=\(simulator) runtime=\(runtime)",
            "xctestPerformanceIterations=\(measuredIterations) manualSubscenarioIterations=\(capturedSamples) " +
                "statisticsSource=manual explicitWarmups=1 selected=categorical firstSwitch=wind " +
                "wallClock=DispatchTime cpuClock=CLOCK_PROCESS_CPUTIME_ID",
            "retainedWork=cached-scene-and-overlay-counts memoryMetric=not-run " +
                "reason=short-lived-simulator-heap-samples-would-not-isolate-per-layer-retention",
            "hitchOrFlash=not-reproduced correlation=not-established harness=materialization-only " +
                "excludedCosts=fetch,planner,rendering,task-scheduling"
        ]
        lines.append(contentsOf: fixtures.map(\.profile.description))

        for series in seriesByKey.values.sorted(by: {
            ($0.fixture, $0.warnings, $0.scenario) < ($1.fixture, $1.warnings, $1.scenario)
        }) {
            lines.append(
                "MAP_SCENE_WARMING fixture=\(series.fixture) warnings=\(series.warnings) scenario=\(series.scenario) " +
                    "iterations=\(series.wallSamples.count) cachedScenes=\(series.cachedSceneCount) " +
                    "cachedOverlays=\(series.cachedOverlayCount) " +
                    "wall{\(statistics(series.wallSamples))} cpu{\(statistics(series.cpuSamples))}"
            )
        }

        return lines.joined(separator: "\n")
    }

    private func statistics(_ samples: [Double]) -> String {
        let sorted = samples.sorted()
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.count > 1
            ? samples.reduce(0) { $0 + pow($1 - mean, 2) } / Double(samples.count - 1)
            : 0
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = mean == 0 ? 0 : standardDeviation / mean
        let p95Index = Int((Double(sorted.count - 1) * 0.95).rounded(.up))

        return "minMs=\(format(sorted[0])) medianMs=\(format(sorted[sorted.count / 2])) " +
            "meanMs=\(format(mean)) p95Ms=\(format(sorted[p95Index])) maxMs=\(format(sorted[sorted.count - 1])) " +
            "stddevMs=\(format(standardDeviation)) cv=\(format(coefficientOfVariation))"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}
