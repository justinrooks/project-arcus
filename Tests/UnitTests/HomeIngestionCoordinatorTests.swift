import Foundation
import Testing
@testable import SkyAware

@Suite("Home Ingestion Coordinator", .serialized)
struct HomeIngestionCoordinatorTests {
    @Test("trigger plans preserve the expected lane selection")
    func triggerPlans_matchExpectedCoverage() {
        let activatePlan = HomeIngestionPlan(
            request: .init(trigger: .foregroundActivate)
        )
        #expect(activatePlan.lanes == .all)
        #expect(activatePlan.forcedLanes.isEmpty)

        let manualPlan = HomeIngestionPlan(
            request: .init(trigger: .manualRefresh)
        )
        #expect(manualPlan.lanes == .all)
        #expect(manualPlan.forcedLanes == .all)

        let tickPlan = HomeIngestionPlan(
            request: .init(trigger: .sessionTick)
        )
        #expect(tickPlan.lanes == [.hotAlerts])
        #expect(tickPlan.forcedLanes.isEmpty)

        let locationPlan = HomeIngestionPlan(
            request: .init(trigger: .foregroundLocationChange)
        )
        #expect(locationPlan.lanes == .all)
        #expect(locationPlan.forcedLanes == [.hotAlerts, .weather])

        let backgroundRefreshPlan = HomeIngestionPlan(
            request: .init(trigger: .backgroundRefresh)
        )
        #expect(backgroundRefreshPlan.lanes == .all)
        #expect(backgroundRefreshPlan.forcedLanes == [.hotAlerts])

        let backgroundLocationPlan = HomeIngestionPlan(
            request: .init(trigger: .backgroundLocationChange)
        )
        #expect(backgroundLocationPlan.lanes == .all)
        #expect(backgroundLocationPlan.forcedLanes == [.hotAlerts, .weather])
    }

    @Test("runs one ingestion plan at a time")
    func enqueue_serializesExecution() async {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.sessionTick)
        let firstStarted = await waitUntil(timeout: .seconds(5)) {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        await coordinator.enqueue(.manualRefresh)

        let stillSerialized = await waitUntil(timeout: .seconds(2)) {
            await executor.startedPlanCount() == 1
        }
        #expect(stillSerialized)

        await gate.open()

        let secondStarted = await waitUntil(timeout: .seconds(5)) {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)
    }

    @Test("merges pending plans by unioning lanes and force requirements")
    func pendingPlan_mergeUnionsRequirements() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)
        let remoteContext = HomeRemoteAlertContext(
            alertID: "alert-123",
            revisionSent: Date(timeIntervalSince1970: 700)
        )

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
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
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
        let executor = FakeHomeIngestionExecutor(beforeHotAlertsGate: gate)
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

    @Test("remote hot-alert requests queue follow-up when active run is not remote-aware")
    func remoteHotAlert_queuesFollowUpWhenActiveRunLacksRemoteContext() async throws {
        let gate = AsyncGate()
        let snapshot = HomeSnapshot(weather: makeWeather())
        let executor = FakeHomeIngestionExecutor(
            snapshot: snapshot,
            beforeHotAlertsGate: gate
        )
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.backgroundRefresh)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        let remoteWaitTask = Task {
            try await coordinator.enqueueAndWait(
                .remoteHotAlertReceived,
                remoteAlertContext: .init(
                    alertID: "alert-456",
                    revisionSent: Date(timeIntervalSince1970: 900)
                )
            )
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await executor.startedPlanCount() == 1)

        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        let resolvedSnapshot = try await remoteWaitTask.value
        #expect(resolvedSnapshot == snapshot)

        let plans = await executor.executedPlans()
        #expect(plans.count == 2)
        #expect(plans[1].remoteAlertContext?.alertID == "alert-456")
    }

    @Test("remote hot-alert requests queue a follow-up once the active run has passed hot-alert sync")
    func remoteHotAlert_queuesFollowUpAfterHotAlertsComplete() async throws {
        let gate = AsyncGate()
        let executor = FakeHomeIngestionExecutor(afterHotAlertsGate: gate)
        let coordinator = HomeIngestionCoordinator(executor: executor)

        await coordinator.enqueue(.backgroundRefresh)
        let firstStarted = await waitUntil {
            await executor.startedPlanCount() == 1
        }
        #expect(firstStarted)

        let hotAlertsCompleted = await waitUntil {
            await executor.completedHotAlertsCount() == 1
        }
        #expect(hotAlertsCompleted)

        let remoteWaitTask = Task {
            try await coordinator.enqueueAndWait(
                .remoteHotAlertReceived,
                remoteAlertContext: .init(
                    alertID: "alert-follow-up",
                    revisionSent: Date(timeIntervalSince1970: 950)
                )
            )
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await executor.startedPlanCount() == 1)

        await gate.open()

        let secondStarted = await waitUntil {
            await executor.startedPlanCount() == 2
        }
        #expect(secondStarted)

        _ = try await remoteWaitTask.value
        let plans = await executor.executedPlans()
        #expect(plans.count == 2)
        #expect(plans[1].remoteAlertContext?.alertID == "alert-follow-up")
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
    private let beforeHotAlertsGate: AsyncGate?
    private let afterHotAlertsGate: AsyncGate?
    private var plans: [HomeIngestionPlan] = []
    private var completedHotAlerts = 0

    init(
        snapshot: HomeSnapshot = .empty,
        beforeHotAlertsGate: AsyncGate? = nil,
        afterHotAlertsGate: AsyncGate? = nil
    ) {
        self.snapshot = snapshot
        self.beforeHotAlertsGate = beforeHotAlertsGate
        self.afterHotAlertsGate = afterHotAlertsGate
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot {
        plans.append(plan)

        if plans.count == 1, let beforeHotAlertsGate {
            await beforeHotAlertsGate.wait()
        }

        completedHotAlerts += 1
        await progress.markHotAlertsCompleted()

        if plans.count == 1, let afterHotAlertsGate {
            await afterHotAlertsGate.wait()
        }

        return snapshot
    }

    func startedPlanCount() -> Int {
        plans.count
    }

    func executedPlans() -> [HomeIngestionPlan] {
        plans
    }

    func completedHotAlertsCount() -> Int {
        completedHotAlerts
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
    // Full-target CI runs can heavily contend actor scheduling for these queueing tests.
    timeout: Duration = .seconds(2),
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
