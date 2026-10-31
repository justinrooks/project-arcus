import ArcusCore
import CoreLocation
import Foundation
import SwiftData
import Testing
import Observation
import Synchronization
import SwiftUI
import UIKit
@testable import SkyAware

@Suite("Home Projection Store Scaling Measurement", .serialized)
@MainActor
struct HomeProjectionStoreScalingMeasurementTests {
    private static let populations = [1, 10, 100, 1_000]
    private static let measuredRepetitions = 9

#if PERFORMANCE_TESTS
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
#else
    @Test("seeded retained projections preserve semantics and operation counts without measurements")
    func seededRetainedProjections_preserveSemanticsAndOperationCounts() async throws {
        for population in Self.populations {
            try await verifyCorrectness(population: population)
            for scenario in [CommitScenario.convectiveOnly, .convectiveAndFire] {
                let first = try await performCommit(population: population, scenario: scenario, recordsTiming: false)
                let second = try await performCommit(population: population, scenario: scenario, recordsTiming: false)
                #expect(first.metrics == second.metrics)
            }
            let fixture = try makeFixture(population: population)
            let observed = try fetchProjections(from: fixture.container)
            #expect(convertAndSelect(observed, currentContext: fixture.target)?.projectionKey == fixture.targetKey)
        }
    }
#endif

#if !PERFORMANCE_TESTS
    @Test("body snapshot sampling preserves selection and observes persisted payload changes")
    func bodySnapshotSamplingPreservesSelectionAndPayloadChanges() throws {
        let fixture = try makeFixture(population: 10)
        let observed = try fetchProjections(from: fixture.container)
        let payload = Data(Self.stormSetupPayload.utf8)
        let response = try #require(StormSetupCurrentResponsePersistenceCodec.decode(payload))
        for projection in observed {
            projection.stormSetupCurrentResponseData = payload
        }
        let snapshot = HomeProjectionObservation.snapshot(in: observed, projectionKey: fixture.targetKey)
        #expect(snapshot.current?.projectionKey == fixture.targetKey)
        #expect(snapshot.current?.stormSetupCurrentResponse == response)
        #expect(snapshot.latestObserved?.id == observed.first?.id)
        #expect(HomeProjectionObservation.snapshot(in: observed, projectionKey: nil).current == nil)
        #expect(HomeProjectionObservation.snapshot(in: observed, projectionKey: "missing").current == nil)

        // No revision-keyed cache: even a payload-only mutation is visible on the next sample.
        let target = try #require(observed.first { $0.projectionKey == fixture.targetKey })
        target.stormSetupCurrentResponseData = nil
        let updated = HomeProjectionObservation.snapshot(in: observed, projectionKey: fixture.targetKey)
        #expect(updated.current?.stormSetupCurrentResponse == nil)
        #expect(updated.current?.updatedAt == snapshot.current?.updatedAt)
    }
#endif

#if PERFORMANCE_TESTS
    @Test("retained Storm Setup projections report repeated versus single body snapshot sampling")
    func retainedStormSetupProjections_reportBodySnapshotSampling() throws {
        let fixture = try makeFixture(population: 10)
        let observed = try fetchProjections(from: fixture.container)
        let payload = Data(Self.stormSetupPayload.utf8)
        try #require(StormSetupCurrentResponsePersistenceCodec.decode(payload)?.profileAnalysis != nil)
        for projection in observed {
            projection.stormSetupCurrentResponseData = payload
        }
        var reports = ["Debug simulator microbenchmark; body access pattern replay, not rendered UI timing. payloadBytes=\(payload.count)"]
        for key in [fixture.targetKey, nil] {
            for sampleOnce in [false, true] {
                var snapshotAccesses = 0
                func snapshot() -> HomeProjectionObservation.Snapshot {
                    snapshotAccesses += 1
                    return HomeProjectionObservation.snapshot(in: observed, projectionKey: key)
                }
                func evaluate() -> HomeProjectionObservation.Snapshot {
                    // Replay pre-fix body reads: revision's observed record and fallback key,
                    // content's startup argument, and onChange's value. Excludes callback work.
                    let sampled = sampleOnce ? snapshot() : nil
                    func read() -> HomeProjectionObservation.Snapshot { sampled ?? snapshot() }
                    let revision = HomeVisibleRevision.derive(
                        previous: nil,
                        observed: key == nil ? read().latestObserved : read().current,
                        projectionKey: key ?? read().latestObserved?.projectionKey
                    )
                    let startup = read().latestObserved
                    let changeValue = read()
                    #expect(revision?.core == (key == nil ? changeValue.latestObserved : changeValue.current))
                    #expect(startup == changeValue.latestObserved)
                    return changeValue
                }
                _ = evaluate() // Warm SwiftData accessors and decoder before timing.
                snapshotAccesses = 0
                var samples: [Double] = []
                for _ in 0..<Self.measuredRepetitions {
                    let start = DispatchTime.now().uptimeNanoseconds
                    _ = evaluate()
                    samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                }
                let reads = sampleOnce ? 1 : (key == nil ? 4 : 3)
                #expect(snapshotAccesses == reads * Self.measuredRepetitions)
                // Each snapshot maps all ten rows, plus the one matching current row, through
                // record. Each populated record invokes exactly one Storm Setup JSON decode.
                let conversions = reads * (observed.count + (key == nil ? 0 : 1))
                reports.append("snapshotReads=\(reads) sourceDerivedRecordConversions=\(conversions) sourceDerivedDecodes=\(conversions) " + MeasurementReport(
                    population: observed.count,
                    scenario: "body-\(key == nil ? "startup" : "keyed")-\(sampleOnce ? "sampled" : "repeated")",
                    samples: samples
                ).description)
            }
        }
        Attachment.record(reports.joined(separator: "\n"), named: "HomeProjectionBodySampling.txt")
    }
#endif

#if PERFORMANCE_TESTS
    @Test("transient presentation publications report scoped and hosted Observation counts")
    func presentationDependencies_reportObservationBreadth() async throws {
        let fixture = try makeFixture(population: 10)
        let observed = try fetchProjections(from: fixture.container)
        let payload = Data(Self.stormSetupPayload.utf8)
        for projection in observed { projection.stormSetupCurrentResponseData = payload }
        let pipeline = HomeRefreshPipeline()
        let current = try #require(observed.first { $0.projectionKey == fixture.targetKey })
        let state = HomeDependencyProbeRevision(revision: HomeVisibleRevision(core: current.record, alerts: nil, enrichment: nil))
        let now = Date(timeIntervalSince1970: 10_010)
        func evaluate(narrow: Bool, staticMode: Bool = false) -> HomeView.HomePresentationSnapshot {
            if narrow {
                return HomeView.presentationSnapshot(
                    now: now, visibleRevision: state.revision, startupProjection: state.revision?.core,
                    currentContext: fixture.target, pipeline: pipeline, isUITestStaticMode: staticMode
                )
            }
            // Baseline replay of main ac714a6's eager production call, without projection decoding.
            let visibleRevision = state.revision
            let startupProjection = visibleRevision?.core
            return HomeView.HomePresentationSnapshot(
                visibleRevision: visibleRevision,
                newestStartupProjection: startupProjection,
                currentContext: fixture.target,
                pipelineSnap: pipeline.snap,
                pipelineStormRisk: pipeline.stormRisk,
                pipelineSevereRisk: pipeline.severeRisk,
                pipelineFireRisk: pipeline.fireRisk,
                pipelineWeather: pipeline.summaryWeather,
                pipelineAirQuality: pipeline.airQuality,
                pipelineMesos: pipeline.mesos,
                pipelineAlerts: pipeline.alerts,
                resolvedLocationScopedRefreshKey: pipeline.lastResolvedLocationScopedRefreshKey,
                alertSnapshotRefreshKey: pipeline.alertSnapshotRefreshKey,
                pipelineStormSetup: pipeline.stormSetup,
                pipelineStormSetupCurrentResponse: pipeline.stormSetupCurrentResponse,
                stormSetupRefreshKey: pipeline.stormSetupRefreshKey,
                isUITestStaticMode: staticMode,
                now: now
            )
        }
        var lines = ["#810 scoped notifications and hosted content evaluations; no rendering/hitch measurement. Timings exclude projection conversion/decode."]
        for narrow in [false, true] {
            for scenario in ["warm-weather", "manual-enrichment", "accepted-core"] {
                let notifications = Mutex(0)
                var changedOutputs = 0
                for index in 0..<20 {
                    let before = withObservationTracking {
                        evaluate(narrow: narrow)
                    } onChange: {
                        notifications.withLock { $0 += 1 }
                    }
                    switch scenario {
                    case "warm-weather":
                        pipeline.summaryWeather = SummaryWeather(
                            temperature: .init(value: Double(index), unit: .fahrenheit),
                            symbolName: "sun.max", conditionText: "Clear", asOf: now,
                            dewPoint: .init(value: 54, unit: .fahrenheit), humidity: 0.45,
                            windSpeed: .init(value: 15, unit: .milesPerHour), windGust: nil,
                            windDirection: "NW", pressure: .init(value: 29.92, unit: .inchesOfMercury),
                            pressureTrend: "steady"
                        )
                    case "manual-enrichment":
                        pipeline.stormSetupCurrentResponse = index.isMultiple(of: 2) ? current.record.stormSetupCurrentResponse : nil
                    default:
                        current.stormRisk = index.isMultiple(of: 2) ? .high : .slight
                        state.revision = HomeVisibleRevision(core: current.record, alerts: nil, enrichment: nil)
                    }
                    let after = evaluate(narrow: narrow)
                    if before.weather != after.weather || before.stormRisk != after.stormRisk ||
                        before.stormSetupCurrentResponse != after.stormSetupCurrentResponse {
                        changedOutputs += 1
                    }
                }
                #expect(notifications.withLock { $0 } == (narrow && scenario != "accepted-core" ? 0 : 20))
                #expect(changedOutputs == (scenario == "accepted-core" ? 20 : 0))
                lines.append("narrow=\(narrow) scenario=\(scenario) mutations=20 notifications=\(notifications.withLock { $0 }) changedOutputs=\(changedOutputs)")
            }
            var samples: [Double] = []
            var consumed = 0
            for _ in 0..<9 {
                let start = DispatchTime.now().uptimeNanoseconds
                for _ in 0..<1000 {
                    let output = evaluate(narrow: narrow)
                    consumed += output.alerts.count + (output.stormRisk == nil ? 0 : 1)
                }
                samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 / 1000)
            }
            lines.append("narrow=\(narrow) consumed=\(consumed) " + MeasurementReport(population: 10, scenario: "presentation-only-per-evaluation-ms", samples: samples).description)
        }
        try current.modelContext?.save()
        for narrow in [false, true] {
            pipeline.snap = fixture.target.snapshot
            let counter = HomeDependencyBodyCounter()
            let context = ModelContext(fixture.container)
            let root = HomeProjectionObservation(projectionKey: fixture.targetKey) { _, _ in
                let output = evaluate(narrow: narrow)
                let _ = { counter.evaluations += 1 }()
                Text(output.stormRisk == nil ? "missing" : "accepted")
            }.environment(\.modelContext, context)
            let host = UIHostingController(rootView: root)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(500))
            let initial = counter.evaluations
            for index in 0..<20 {
                pipeline.snap = index.isMultiple(of: 2) ? nil : fixture.target.snapshot
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(initial > 0)
            #expect(counter.evaluations - initial == (narrow ? 0 : 20))
            lines.append("HOSTED narrow=\(narrow) warm-transient-steps=20 initialContentEvaluations=\(initial) additionalContentEvaluations=\(counter.evaluations - initial)")
            window.isHidden = true
            window.rootViewController = nil
            try await Task.sleep(for: .milliseconds(100))
            withExtendedLifetime((host, window, context, fixture.container)) {}
        }
        // Static mode continues reading and presenting pipeline weather in the candidate.
        state.revision = nil
        let staticResult = evaluate(narrow: true, staticMode: true)
        #expect(staticResult.weather == pipeline.summaryWeather)
        Attachment.record(lines.joined(separator: "\n"), named: "HomePresentationDependencies810.txt")
    }
#endif

#if !PERFORMANCE_TESTS
    @Test("production ignores transient payloads while static mode observes and presents them", arguments: [false, true])
    func presentationDependenciesPreserveAcceptedAndStaticState(staticMode: Bool) throws {
        let fixture = try makeFixture(population: 1)
        let observed = try fetchProjections(from: fixture.container)
        let core = try #require(observed.first).record
        let pipeline = HomeRefreshPipeline(initialSnap: fixture.target.snapshot)
        let notifications = Mutex(0)
        func snapshot(revision: HomeVisibleRevision?) -> HomeView.HomePresentationSnapshot {
            HomeView.presentationSnapshot(
                now: .init(timeIntervalSince1970: 10_010), visibleRevision: revision, startupProjection: core,
                currentContext: fixture.target, pipeline: pipeline, isUITestStaticMode: staticMode
            )
        }
        let before = withObservationTracking {
            snapshot(revision: nil)
        } onChange: {
            notifications.withLock { $0 += 1 }
        }
        #expect(before.locationSnapshot == (staticMode ? fixture.target.snapshot : nil))
        pipeline.snap = nil
        #expect(notifications.withLock { $0 } == (staticMode ? 1 : 0))
        #expect(snapshot(revision: nil).locationSnapshot == nil)
        let accepted = snapshot(revision: HomeVisibleRevision(core: core, alerts: nil, enrichment: nil))
        #expect(accepted.projection == core)
        #expect(accepted.locationSnapshot == core.locationSnapshot)
        #expect(accepted.stormRisk == core.stormRisk)
    }
#endif

    // Representative detailed response: HRRR metadata, canonical/diagnostic ingredients,
    // embedded Anvil analysis, and viability. No network or raw atmospheric profile is needed.
    private static let stormSetupPayload = #"""
    {
      "setup": {
        "h3Cell": 1000000, "centroid": {"latitude": 39.75, "longitude": -104.44},
        "source": {"sourceKind": "nomadsFilteredSubset", "model": "HRRR", "product": "wrfsfc", "domain": "conus", "runTime": "2026-06-01T18:00:00Z", "forecastHour": 3, "validTime": "2026-06-01T21:00:00Z", "fieldSetVersion": "tornado-v1", "bbox": {"leftlon": -104.3, "rightlon": -96.2, "toplat": 41.5, "bottomlat": 36.8}},
        "surfaceHeightMslM": 1340,
        "freshness": {"sourceValidTime": "2026-06-01T21:00:00Z", "modelRunTime": "2026-06-01T18:00:00Z", "forecastHour": 3, "fetchedAt": "2026-06-01T21:03:00Z", "expiresAt": "2026-06-01T22:00:00Z", "isStale": false, "isDegraded": false}
      },
      "ingredients": {
        "canonical": {"sbcapeJkg": 1700, "mlcapeJkg": 1850, "mucapeJkg": 2200.5, "mlcinJkg": -42, "mllclM": 980, "tempDewPtDeltaF": 4.5, "threeCapeJkg": 95, "shear06kmKt": 42, "shear03kmKt": 31, "shear01kmKt": 18, "srh01kmM2s2": 125.5, "srh03kmM2s2": 175},
        "diagnostics": {"effectiveBulkShearMs": 24.5, "effectiveSrhM2s2": 135, "supercellComposite": 0.7, "significantTornadoFixed": 1.2, "significantHail": 2.1}
      },
      "profileAnalysis": {"effectiveLayer": {"status": "found", "basePressureMb": 915, "topPressureMb": 750, "baseMetersAgl": 850, "topMetersAgl": 1800}, "stormMotion": {"status": "found", "bunkersRight": {"uKt": 12, "vKt": -8, "speedKt": 18, "directionTowardDeg": 215, "uMs": 6.2, "vMs": -4.1, "speedMs": 9.2}}, "mucape": 2200.5, "mlcape": 1850, "mlcin": -42, "mllclMetersAgl": 980, "effectiveSrh": 135, "effectiveBulkShearMs": 24.5, "scp": 0.7, "stpCin": 0.9, "stpFixed": 1.2, "ship": 2.1, "quality": {"profileLevelCount": 36, "warnings": []}},
      "tornadoViability": {"overall": "supportive", "realization": "realized", "primaryFailureMode": "none", "confidence": "moderate", "summary": "Supportive setup with instability, deep shear, and low-level rotation.", "details": {"stormViability": "supportive", "supercellViability": "strong", "tornadoEfficiency": "supportive", "inhibition": "weak", "instability": "supportive", "moisture": "strong", "cloudBase": "weak", "deepShear": "strong", "lowLevelRotation": "conditional", "lowLevelStretching": "supportive", "cloudBaseEfficiency": "supportive", "supercellComposite": "strong", "tornadoComposite": "supportive", "stormMode": "conditional"}, "limitingFactors": []}
    }
    """#

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
        #expect(sourceKey(inherited.convectiveRiskComparisonSourceKey) == inheritedSource.persistenceToken)
        #expect(sourceKey(inherited.fireRiskComparisonSourceKey) == (population == 1 ? inheritedSource.persistenceToken : nil))
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
        #expect(try #require(accepted.riskProfileChange).changedDimensions == [.storm, .severe])

        projections = try fetchProjections(from: fixture.container)
        let current = try #require(projections.first(where: { $0.projectionKey == fixture.targetKey }))
        #expect(sourceKey(current.convectiveRiskComparisonSourceKey) == acceptedSource.persistenceToken)
        #expect(sourceKey(current.fireRiskComparisonSourceKey) == (population == 1 ? inheritedSource.persistenceToken : nil))
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
        #expect(sourceKey(mixedDomain.convectiveRiskComparisonSourceKey) == acceptedSource.persistenceToken)
        #expect(sourceKey(mixedDomain.fireRiskComparisonSourceKey) == acceptedSource.persistenceToken)
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
        scenario: CommitScenario,
        recordsTiming: Bool = true
    ) async throws -> CommitMeasurementSample {
        let fixture = try makeFixture(population: population)
        let store = HomeProjectionStore(modelContainer: fixture.container)
        await store.resetOperationMetricsForTesting()

        let start = recordsTiming ? DispatchTime.now().uptimeNanoseconds : 0
        _ = try await store.commitCore(
            scenario.commit(source: source(revision: 2)),
            for: fixture.target,
            loadedAt: .init(timeIntervalSince1970: 30_000)
        )
        let elapsed = recordsTiming ? DispatchTime.now().uptimeNanoseconds - start : 0
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

    private func sourceKey(_ token: String?) -> String? {
        RiskComparisonBaselineState.decode(token)?.baselineSourceKey
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
#if PERFORMANCE_TESTS
@MainActor
@Observable
private final class HomeDependencyProbeRevision {
    var revision: HomeVisibleRevision?
    init(revision: HomeVisibleRevision?) { self.revision = revision }
}
#endif

#if PERFORMANCE_TESTS
@MainActor
private final class HomeDependencyBodyCounter {
    var evaluations = 0
}
#endif
