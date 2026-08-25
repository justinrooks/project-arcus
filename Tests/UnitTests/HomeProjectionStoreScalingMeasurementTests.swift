import ArcusCore
import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("Home Projection Store Scaling Measurement", .serialized)
@MainActor
struct HomeProjectionStoreScalingMeasurementTests {
    private static let populations = [1, 10, 100, 1_000]
    private static let measuredRepetitions = 9

    @Test("seeded retained projections preserve baseline semantics and report scan scaling")
    func seededRetainedProjections_reportBaselineAndPresentationScaling() async throws {
        for population in Self.populations {
            try await verifyCorrectness(population: population)
        }

        var reports: [MeasurementReport] = []
        for population in Self.populations {
            reports.append(try await measureCommit(population: population, scenario: .convectiveOnly))
            reports.append(try await measureCommit(population: population, scenario: .convectiveAndFire))
            reports.append(try measurePresentation(population: population))
        }

        Attachment.record(
            reports.map(\.description).joined(separator: "\n"),
            named: "HomeProjectionScalingMeasurement.txt"
        )
    }

    private func verifyCorrectness(population: Int) async throws {
        let fixture = try makeFixture(population: population, baselineOnTarget: population == 1)
        let store = HomeProjectionStore(modelContainer: fixture.container)
        let inheritedSource = source(revision: 1)
        let acceptedSource = source(revision: 2)

        _ = try await store.commitCore(
            .init(
                slowProducts: (.slight, .wind(probability: 0.15), nil),
                updatesConvectiveRisk: true,
                updatesFireRisk: false
            ),
            for: fixture.target,
            loadedAt: .init(timeIntervalSince1970: 20_000)
        )

        var projections = try fetchProjections(from: fixture.container)
        let inherited = try #require(projections.first(where: { $0.projectionKey == fixture.targetKey }))
        #expect(inherited.convectiveRiskComparisonSourceKey == inheritedSource.persistenceToken)
        #expect(inherited.fireRiskComparisonSourceKey == (population == 1 ? inheritedSource.persistenceToken : nil))
        #expect(projections.filter { $0.id != inherited.id }.allSatisfy {
            $0.convectiveRiskComparisonSourceKey == nil
        })

        let accepted = try #require(await store.commitCore(
            .init(
                slowProducts: (.enhanced, .tornado(probability: 0.30), nil),
                updatesConvectiveRisk: true,
                updatesFireRisk: false,
                convectiveSource: acceptedSource
            ),
            for: fixture.target,
            loadedAt: .init(timeIntervalSince1970: 20_010)
        ))
        #expect(accepted.changedDimensions == [.storm, .severe])

        projections = try fetchProjections(from: fixture.container)
        let current = try #require(projections.first(where: { $0.projectionKey == fixture.targetKey }))
        #expect(current.convectiveRiskComparisonSourceKey == acceptedSource.persistenceToken)
        #expect(current.fireRiskComparisonSourceKey == (population == 1 ? inheritedSource.persistenceToken : nil))
        #expect(HomeView.selectProjection(from: projections.map(\.record), currentContext: fixture.target)?.projectionKey == fixture.targetKey)

        _ = try await store.commitCore(
            .init(
                slowProducts: (nil, nil, .critical),
                updatesConvectiveRisk: false,
                updatesFireRisk: true,
                fireSource: acceptedSource
            ),
            for: fixture.target,
            loadedAt: .init(timeIntervalSince1970: 20_020)
        )

        projections = try fetchProjections(from: fixture.container)
        let mixedDomain = try #require(projections.first(where: { $0.projectionKey == fixture.targetKey }))
        #expect(mixedDomain.convectiveRiskComparisonSourceKey == acceptedSource.persistenceToken)
        #expect(mixedDomain.fireRiskComparisonSourceKey == acceptedSource.persistenceToken)
        #expect(projections.filter { $0.id != mixedDomain.id }.allSatisfy {
            $0.convectiveRiskComparisonSourceKey == nil && $0.fireRiskComparisonSourceKey == nil
        })
    }

    private func measureCommit(population: Int, scenario: CommitScenario) async throws -> MeasurementReport {
        _ = try await performCommit(population: population, scenario: scenario)

        let first = try await performCommit(population: population, scenario: scenario)
        var samples = [first.durationMilliseconds]
        for _ in 1..<Self.measuredRepetitions {
            let result = try await performCommit(population: population, scenario: scenario)
            samples.append(result.durationMilliseconds)
            #expect(first.metrics == result.metrics)
        }

        return MeasurementReport(
            population: population,
            scenario: scenario.rawValue,
            samples: samples,
            metrics: first.metrics
        )
    }

    private func performCommit(
        population: Int,
        scenario: CommitScenario
    ) async throws -> CommitMeasurementSample {
        let fixture = try makeFixture(population: population)
        let store = HomeProjectionStore(modelContainer: fixture.container)
        await store.resetOperationMetricsForTesting()

        let start = DispatchTime.now().uptimeNanoseconds
        _ = try await store.commitCore(
            scenario.commit(source: source(revision: 2)),
            for: fixture.target,
            loadedAt: .init(timeIntervalSince1970: 30_000)
        )
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let metrics = await store.operationMetricsForTesting()

        #expect(metrics.fetchCount == scenario.fetchCount)
        #expect(metrics.rowsFetched == scenario.rowsFetched(population: population))
        #expect(metrics.comparisonBaselineWriteCount == scenario.baselineWrites(population: population))
        #expect(metrics.comparisonBaselineChangedCount == scenario.baselineChanges(population: population))
        #expect(metrics.saveCount == 1)

        return CommitMeasurementSample(
            durationMilliseconds: Double(elapsed) / 1_000_000,
            metrics: metrics
        )
    }

    private func measurePresentation(population: Int) throws -> MeasurementReport {
        let fixture = try makeFixture(population: population)
        let observed = try fetchProjections(from: fixture.container)

        _ = convertAndSelect(observed, currentContext: fixture.target)
        let samples = (0..<Self.measuredRepetitions).map { _ in
            let start = DispatchTime.now().uptimeNanoseconds
            let selected = convertAndSelect(observed, currentContext: fixture.target)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            #expect(selected?.projectionKey == fixture.targetKey)
            return Double(elapsed) / 1_000_000
        }

        return MeasurementReport(population: population, scenario: "presentation-convert-select", samples: samples)
    }

    private func convertAndSelect(
        _ observed: [HomeProjection],
        currentContext: LocationContext
    ) -> HomeProjectionRecord? {
        HomeView.selectProjection(from: observed.map(\.record), currentContext: currentContext)
    }

    private func makeFixture(population: Int, baselineOnTarget: Bool = false) throws -> Fixture {
        let container = try TestStore.container(for: [HomeProjection.self])
        let context = ModelContext(container)
        let target = locationContext(index: 0)
        let targetKey = HomeProjection.projectionKey(for: target)
        let baselineSource = source(revision: 1).persistenceToken

        for index in 0..<population {
            let location = locationContext(index: index)
            let projection = HomeProjection(
                context: location,
                createdAt: .init(timeIntervalSince1970: 10_000 + Double(index))
            )
            projection.stormRisk = .marginal
            projection.severeRisk = .allClear
            projection.fireRisk = .clear
            projection.lastWeatherLoadAt = .init(timeIntervalSince1970: 10_001)
            projection.lastSlowProductsLoadAt = .init(timeIntervalSince1970: 10_002)
            projection.lastHotAlertsLoadAt = .init(timeIntervalSince1970: 10_003)

            if index == 1 || (baselineOnTarget && index == 0) {
                let comparisonKey = HomeProjection.riskComparisonLocationKey(for: location)
                projection.convectiveRiskComparisonLocationKey = comparisonKey
                projection.convectiveRiskComparisonSourceKey = baselineSource
                projection.fireRiskComparisonLocationKey = comparisonKey
                projection.fireRiskComparisonSourceKey = baselineSource
            }
            context.insert(projection)
        }
        try context.save()

        return Fixture(container: container, target: target, targetKey: targetKey)
    }

    private func fetchProjections(from container: ModelContainer) throws -> [HomeProjection] {
        try ModelContext(container).fetch(
            FetchDescriptor(sortBy: [SortDescriptor(\HomeProjection.updatedAt, order: .reverse)])
        )
    }

    private func locationContext(index: Int) -> LocationContext {
        let latitude = 39.75 + Double(index) / 10_000
        let longitude = -104.44 - Double(index) / 10_000
        let h3Cell = Int64(1_000_000 + index)
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: .init(timeIntervalSince1970: 10_000 + Double(index)),
            accuracy: 25,
            placemarkSummary: "Fixture \(index)",
            h3Cell: h3Cell
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/\(index),\(index)",
            latitude: latitude,
            longitude: longitude,
            gridId: "BOU",
            gridX: index,
            gridY: index,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Fixture",
            state: "CO",
            timeZoneId: "America/Denver",
            radarStationId: nil,
            forecastZone: "COZ\(index)",
            countyCode: "COC\(index)",
            fireZone: "COZ\(10_000 + index)",
            countyLabel: "Fixture County",
            fireZoneLabel: "Fixture Fire Zone"
        )
        return LocationContext(snapshot: snapshot, h3Cell: h3Cell, grid: grid)
    }

    private func source(revision: TimeInterval) -> SpcMapSourceIdentity {
        .forecast(
            issued: .init(timeIntervalSince1970: revision * 100),
            valid: .init(timeIntervalSince1970: revision * 100 + 10),
            expires: .init(timeIntervalSince1970: revision * 100 + 90)
        )
    }
}

private enum CommitScenario: String {
    case convectiveOnly = "core-commit-convective-only"
    case convectiveAndFire = "core-commit-convective-plus-fire"

    var fetchCount: Int {
        switch self {
        case .convectiveOnly: 2
        case .convectiveAndFire: 3
        }
    }

    func rowsFetched(population: Int) -> Int {
        switch self {
        case .convectiveOnly: population == 1 ? 1 : 2
        case .convectiveAndFire: population == 1 ? 1 : 3
        }
    }

    func baselineWrites(population: Int) -> Int {
        switch self {
        case .convectiveOnly: population == 1 ? 1 : 2
        case .convectiveAndFire: population == 1 ? 2 : 4
        }
    }

    func baselineChanges(population: Int) -> Int {
        switch self {
        case .convectiveOnly: population == 1 ? 1 : 2
        case .convectiveAndFire: population == 1 ? 2 : 4
        }
    }

    func commit(source: SpcMapSourceIdentity) -> HomeProjectionCoreCommit {
        switch self {
        case .convectiveOnly:
            .init(
                slowProducts: (.enhanced, .tornado(probability: 0.30), nil),
                updatesConvectiveRisk: true,
                updatesFireRisk: false,
                convectiveSource: source
            )
        case .convectiveAndFire:
            .init(
                slowProducts: (.enhanced, .tornado(probability: 0.30), .critical),
                convectiveSource: source,
                fireSource: source
            )
        }
    }
}

private struct Fixture {
    let container: ModelContainer
    let target: LocationContext
    let targetKey: String
}

private struct CommitMeasurementSample {
    let durationMilliseconds: Double
    let metrics: HomeProjectionStoreOperationMetrics
}

private struct MeasurementReport: CustomStringConvertible {
    let population: Int
    let scenario: String
    let samples: [Double]
    let metrics: HomeProjectionStoreOperationMetrics?

    init(
        population: Int,
        scenario: String,
        samples: [Double],
        metrics: HomeProjectionStoreOperationMetrics? = nil
    ) {
        self.population = population
        self.scenario = scenario
        self.samples = samples
        self.metrics = metrics
    }

    var description: String {
        let sorted = samples.sorted()
        let p95Index = Int((Double(sorted.count - 1) * 0.95).rounded(.up))
        let durations = sorted.map { String(format: "%.3f", $0) }.joined(separator: ",")
        let metricSummary = metrics.map {
            " fetches=\($0.fetchCount) rowsFetched=\($0.rowsFetched) baselineWrites=\($0.comparisonBaselineWriteCount) baselineChanges=\($0.comparisonBaselineChangedCount) saves=\($0.saveCount)"
        } ?? ""
        return "PROJECTION_SCALING population=\(population) scenario=\(scenario) samplesMs=[\(durations)] minMs=\(String(format: "%.3f", sorted[0])) medianMs=\(String(format: "%.3f", sorted[sorted.count / 2])) p95Ms=\(String(format: "%.3f", sorted[p95Index])) maxMs=\(String(format: "%.3f", sorted[sorted.count - 1]))\(metricSummary)"
    }
}
