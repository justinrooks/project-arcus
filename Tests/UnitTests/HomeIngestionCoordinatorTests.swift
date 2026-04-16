import Foundation
import Testing
@testable import SkyAware

@Suite("Home Ingestion Coordinator")
struct HomeIngestionCoordinatorTests {
    @Test("runs one ingestion plan at a time")
    func enqueue_serializesExecution() async {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(runGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.manualRefresh)

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await executor.startedPlanCount() == 1)

        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)
    }

    @Test("merges pending plans by unioning lanes and force requirements")
    func pendingPlan_mergeUnionsRequirements() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(runGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let remoteContext = HomeRemoteAlertContext(eventKey: "event-123", revision: 7)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.foregroundActivate)
        await coordinator.enqueue(.remoteHotAlertReceived, remoteAlertContext: remoteContext)
        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let plans = await executor.executedPlans()
        #expect(plans.count == 2)

        let merged = try #require(plans.last)
        #expect(merged.lanes == .all)
        #expect(merged.forcedLanes == [.hotAlerts])
        #expect(merged.remoteAlertContext == remoteContext)
        #expect(merged.provenance.contains(.foregroundActivate))
        #expect(merged.provenance.contains(.remoteHotAlertReceived))
    }

    @Test("manual refresh escalates a queued follow-up plan to a full forced refresh")
    func manualRefresh_escalatesPendingWork() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(runGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.backgroundRefresh)
        await coordinator.enqueue(.manualRefresh)
        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let merged = try #require(await executor.executedPlans().last)
        #expect(merged.lanes == .all)
        #expect(merged.forcedLanes == .all)
        #expect(merged.provenance.contains(.background))
        #expect(merged.provenance.contains(.manualRefresh))
    }

    @Test("newest location-bearing request wins when pending work is merged")
    func locationBearingRequest_replacesOlderPendingLocation() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(runGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let firstContext = makeContext(latitude: 39.75, longitude: -104.44, timestamp: 100)
        let secondContext = makeContext(latitude: 39.90, longitude: -104.10, timestamp: 200)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.foregroundLocationChange, locationContext: firstContext)
        await coordinator.enqueue(.backgroundLocationChange, locationContext: secondContext)
        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let merged = try #require(await executor.executedPlans().last)
        switch merged.locationRequest {
        case .explicit(let context):
            #expect(context == secondContext)
        default:
            Issue.record("Expected explicit location context for merged location-bearing plan")
        }
    }

    @Test("remote hot-alert requests can wait on an already-sufficient active plan")
    func remoteHotAlert_attachesToSufficientActiveRun() async throws {
        let gate = AsyncGate()
        let snapshot = HomeSnapshot(weather: makeWeather())
        let executor = FakeHomeIngestionExecutor(snapshot: snapshot, runGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.backgroundRefresh)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        let remoteWaitTask = Task {
            try await coordinator.enqueueAndWait(
                .remoteHotAlertReceived,
                remoteAlertContext: .init(eventKey: "event-456", revision: 9)
            )
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await executor.startedPlanCount() == 1)

        await gate.open()

        let resolvedSnapshot = try await remoteWaitTask.value
        #expect(resolvedSnapshot == snapshot)
        #expect(await executor.startedPlanCount() == 1)
    }

    private func makeContext(
        latitude: Double,
        longitude: Double,
        timestamp: TimeInterval
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: 123_456
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: latitude,
            longitude: longitude,
            gridId: "BOU",
            gridX: 10,
            gridY: 20,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Bennett",
            state: "CO",
            timeZoneId: "America/Denver",
            radarStationId: nil,
            forecastZone: "COZ038",
            countyCode: "COC005",
            fireZone: "COZ214",
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: snapshot.h3Cell ?? 123_456, grid: grid)
    }

    private func makeWeather() -> SummaryWeather {
        SummaryWeather(
            temperature: .init(value: 72, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: Date(timeIntervalSince1970: 200),
            dewPoint: .init(value: 54, unit: .fahrenheit),
            humidity: 0.45,
            windSpeed: .init(value: 15, unit: .milesPerHour),
            windGust: .init(value: 24, unit: .milesPerHour),
            windDirection: "NW",
            pressure: .init(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
    }
}

private actor FakeHomeIngestionExecutor: HomeIngestionExecuting {
    private let snapshot: HomeSnapshot
    private let runGate: AsyncGate?
    private var plans: [HomeIngestionPlan] = []

    init(
        snapshot: HomeSnapshot = .empty,
        runGate: AsyncGate? = nil
    ) {
        self.snapshot = snapshot
        self.runGate = runGate
    }

    func run(plan: HomeIngestionPlan) async throws -> HomeSnapshot {
        plans.append(plan)

        if plans.count == 1, let runGate {
            await runGate.wait()
        }

        return snapshot
    }

    func startedPlanCount() -> Int {
        plans.count
    }

    func executedPlans() -> [HomeIngestionPlan] {
        plans
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
