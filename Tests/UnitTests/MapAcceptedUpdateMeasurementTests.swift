import ArcusCore
import Darwin
import Foundation
import MapKit
import XCTest
@testable import SkyAware

@MainActor
final class MapAcceptedUpdateMeasurementTests: XCTestCase {
    private static let repetitions = 8

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

            for _ in 0..<Self.repetitions {
                await counts.reset()
                if feedID != nil { model.invalidateAcceptedInputs() }
                let start = ContinuousClock.now
                var cpuStart = timespec()
                clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpuStart)
                await model.reload(using: spc, mesoSource: meso, warningSource: alerts, selectedLayer: .categorical)
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

    init(counts: MapAcceptedUpdateReadCounts) { self.counts = counts }

    func setDay2Revision(_ revision: Int) { day2Revision = revision }
    func setDay3Revision(_ revision: Int) { day3Revision = revision }

    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        await counts.record("severe")
        return []
    }

    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        await counts.record("categorical-current")
        return [makeStormRisk(level: .slight, title: "current")]
    }

    func getMesoMapData() async throws -> [MdDTO] { [] }
    func getFireRisk() async throws -> [FireRiskDTO] {
        await counts.record("fire")
        return []
    }

    func getCategoricalForecast(for day: SPCForecastDay) async throws -> SPCCategoricalForecastSnapshot? {
        await counts.record("categorical-day\(day.rawValue)")
        let revision = day == .day2 ? day2Revision : day == .day3 ? day3Revision : 0
        return measurementForecastSnapshot(day: day, revision: revision)
    }

    func getHazardForecast(for day: SPCForecastDay) async throws -> SPCHazardForecastSnapshot? {
        await counts.record("hazards-day\(day.rawValue)")
        guard day == .day2 else { return nil }
        let category = measurementForecastSnapshot(day: day)
        return SPCHazardForecastSnapshot(
            day: day,
            issued: category.issued.addingTimeInterval(-60),
            valid: category.valid,
            expires: category.expires,
            shapes: [makeSevereRisk(type: .wind, probability: .percent(0.15), title: "Day 2 wind")]
        )
    }
}

private func measurementForecastSnapshot(
    day: SPCForecastDay,
    revision: Int = 0
) -> SPCCategoricalForecastSnapshot {
    let issued = Date(timeIntervalSince1970: 1_735_689_600).addingTimeInterval(Double(revision) * 60)
    return SPCCategoricalForecastSnapshot(
        day: day,
        issued: issued,
        valid: issued.addingTimeInterval(Double(day.rawValue) * 86_400),
        expires: issued.addingTimeInterval(4 * 86_400),
        risks: [makeStormRisk(level: .slight, title: "day\(day.rawValue)-r\(revision)")]
    )
}

private actor CountedMapMesoSource: ArcusMesoQuerying {
    private let counts: MapAcceptedUpdateReadCounts

    init(counts: MapAcceptedUpdateReadCounts) { self.counts = counts }

    func getActiveMesos(h3Cell: Int64?) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]> {
        await counts.record("meso")
        return ArcusMesoQueryResponse(value: [], source: .live)
    }

    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>? { nil }
}

private actor CountedMapAlertSource: ArcusAlertQuerying {
    private let counts: MapAcceptedUpdateReadCounts
    private var warnings: [ActiveWarningGeometry] = []

    init(counts: MapAcceptedUpdateReadCounts) { self.counts = counts }

    func setWarnings(_ warnings: [ActiveWarningGeometry]) { self.warnings = warnings }
    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] { [] }
    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        await counts.record("warnings")
        return warnings
    }
    func getAlert(id: String) async throws -> AlertDTO? { nil }
}
