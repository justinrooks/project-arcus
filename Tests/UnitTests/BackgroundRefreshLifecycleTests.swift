import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("Background refresh lifecycle", .serialized)
struct BackgroundRefreshLifecycleTests {
    @Test("Fallback scheduling completes before blocked orchestration starts")
    func fallbackCompletesBeforeBlockedOrchestrationStarts() async {
        let recorder = LifecycleRecorder()
        let gate = LifecycleGate()
        let nextRun = Date(timeIntervalSince1970: 1_000)
        let lifecycle = makeLifecycle(recorder: recorder, gate: gate, outcome: outcome(next: nextRun, result: .success))

        let task = Task { await lifecycle.run() }
        await recorder.waitForOrchestrationStart()

        #expect(await recorder.events() == ["fallback-complete", "orchestration-start"])

        await gate.open()
        _ = await task.value
        #expect(await recorder.events() == [
            "fallback-complete",
            "orchestration-start",
            "authoritative-\(nextRun.timeIntervalSince1970)"
        ])
    }

    @Test("Completed orchestration schedules its evaluated next run authoritatively")
    func completedOrchestrationSchedulesEvaluatedNextRun() async {
        let recorder = LifecycleRecorder()
        let nextRun = Date(timeIntervalSince1970: 2_000)
        let lifecycle = makeLifecycle(
            recorder: recorder,
            gate: nil,
            outcome: outcome(next: nextRun, result: .success)
        )

        _ = await lifecycle.run()

        #expect(await recorder.authoritativeRuns() == [nextRun])
    }

    @Test("Every terminal orchestrator outcome follows fallback-first scheduling")
    func everyTerminalOutcomeFollowsFallbackFirstScheduling() async {
        let results: [Outcome.BackgroundResult] = [.success, .cancelled, .failed, .skipped]

        for (index, result) in results.enumerated() {
            let recorder = LifecycleRecorder()
            let nextRun = Date(timeIntervalSince1970: Double(index + 1))
            let lifecycle = makeLifecycle(
                recorder: recorder,
                gate: nil,
                outcome: outcome(next: nextRun, result: result)
            )

            _ = await lifecycle.run()

            #expect(await recorder.events() == [
                "fallback-complete",
                "orchestration-start",
                "authoritative-\(nextRun.timeIntervalSince1970)"
            ])
        }
    }

    @Test("Cancellation after fallback leaves the accepted fallback intact")
    func cancellationAfterFallbackLeavesAcceptedFallbackIntact() async {
        let recorder = LifecycleRecorder()
        let gate = LifecycleGate()
        let nextRun = Date(timeIntervalSince1970: 3_000)
        let lifecycle = makeLifecycle(recorder: recorder, gate: gate, outcome: outcome(next: nextRun, result: .cancelled))

        let task = Task { await lifecycle.run() }
        await recorder.waitForOrchestrationStart()
        task.cancel()

        #expect(await recorder.fallbackAttempts() == 1)
        #expect(await recorder.acceptedFallbacks() == 1)

        await gate.open()
        _ = await task.value
    }

    @Test("Fallback submission failure is observable as failure")
    func fallbackSubmissionFailureIsObservableAsFailure() async throws {
        let backend = RecordingSchedulingBackend(pending: .none, submissionResults: [.failure])
        let scheduler = BackgroundScheduler(refreshId: "test.refresh", backend: backend)

        let result = await scheduler.ensureScheduled(
            using: RefreshPolicy(),
            now: Date(timeIntervalSince1970: 0)
        )

        #expect(result == .submissionFailed)
        let submissions = await backend.submittedRuns()
        let submittedRun = try #require(submissions.first)
        #expect(submissions.count == 1)
        #expect(submittedRun >= Date(timeIntervalSince1970: 20 * 60))
        #expect(submittedRun <= Date(timeIntervalSince1970: 22 * 60))
    }

    @Test("Fallback submission failure still allows the authoritative attempt")
    func fallbackSubmissionFailureStillAllowsAuthoritativeAttempt() async {
        let nextRun = Date(timeIntervalSince1970: 5_000)
        let backend = RecordingSchedulingBackend(
            pending: .none,
            submissionResults: [.failure, .success]
        )
        let scheduler = BackgroundScheduler(refreshId: "test.refresh", backend: backend)
        let lifecycle = BackgroundRefreshLifecycle(
            beginRun: { Self.transientRun() },
            scheduleFallback: {
                await scheduler.ensureScheduled(using: RefreshPolicy(), now: .distantPast)
            },
            runOrchestration: { _ in
                .init(next: nextRun, result: .failed, didNotify: false, feedsChanged: [])
            },
            scheduleAuthoritative: { nextRun in
                await scheduler.scheduleEvaluatedNextAppRefresh(nextRun: nextRun)
            }
        )

        _ = await lifecycle.run()

        #expect(await backend.submittedRuns().last == nextRun)
    }

    @Test("Failed authoritative replacement restores the previous fallback")
    func failedAuthoritativeReplacementRestoresPreviousFallback() async {
        let previousRun = Date(timeIntervalSince1970: 4_000)
        let requestedRun = Date(timeIntervalSince1970: 8_000)
        let backend = RecordingSchedulingBackend(
            pending: .at(previousRun),
            submissionResults: [.failure, .success]
        )
        let scheduler = BackgroundScheduler(refreshId: "test.refresh", backend: backend)

        let result = await scheduler.scheduleEvaluatedNextAppRefresh(nextRun: requestedRun)

        #expect(result == .restoredPrevious)
        #expect(await backend.operations() == [
            .cancel,
            .submit(requestedRun),
            .submit(previousRun)
        ])
    }

    @Test("Lifecycle records fallback and authoritative results on the same run")
    func lifecycle_recordsBothSchedulingOutcomesOnRun() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        let store = BgHealthStore(modelContainer: container)
        try await store.start(runId: "scheduled-run", startedAt: .distantPast)
        let run = BackgroundRefreshRun(
            runId: "scheduled-run",
            startedAt: .distantPast,
            schedulingRecorder: { phase, outcome in
                try? await store.recordScheduling(
                    runId: "scheduled-run",
                    phase: phase,
                    outcome: outcome
                )
            }
        )
        let result = Outcome(
            next: Date(timeIntervalSince1970: 1_000),
            result: .success,
            didNotify: false,
            feedsChanged: []
        )
        let lifecycle = BackgroundRefreshLifecycle(
            beginRun: { run },
            scheduleFallback: { .submissionFailed },
            runOrchestration: { _ in result },
            scheduleAuthoritative: { _ in .restoredPrevious }
        )

        _ = await lifecycle.run()

        let snapshot = try #require(await waitForBackgroundRun(id: "scheduled-run", in: container) {
            $0.fallbackSchedulingOutcome == .submissionFailed
                && $0.authoritativeSchedulingOutcome == .restoredPrevious
        })
        #expect(snapshot.fallbackSchedulingOutcome == .submissionFailed)
        #expect(snapshot.authoritativeSchedulingOutcome == .restoredPrevious)
    }

    @Test("Fallback scheduling is durable before blocked orchestration finishes")
    func fallbackScheduling_isDurableBeforeOrchestrationFinishes() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        let store = BgHealthStore(modelContainer: container)
        let gate = LifecycleGate()
        let recorder = LifecycleRecorder()
        let runId = "interrupted-run"
        let lifecycle = BackgroundRefreshLifecycle(
            beginRun: {
                try? await store.start(runId: runId, startedAt: .distantPast)
                return BackgroundRefreshRun(
                    runId: runId,
                    startedAt: .distantPast,
                    schedulingRecorder: { phase, outcome in
                        try? await store.recordScheduling(runId: runId, phase: phase, outcome: outcome)
                    }
                )
            },
            scheduleFallback: { .submitted },
            runOrchestration: { _ in
                await recorder.recordOrchestrationStart()
                await gate.wait()
                return .init(next: .distantFuture, result: .success, didNotify: false, feedsChanged: [])
            },
            scheduleAuthoritative: { _ in .submitted }
        )

        let task = Task { await lifecycle.run() }
        await recorder.waitForOrchestrationStart()

        let snapshot = try #require(await waitForBackgroundRun(id: runId, in: container) {
            $0.fallbackSchedulingOutcome == .submitted
        })
        #expect(snapshot.fallbackSchedulingOutcome == .submitted)
        #expect(snapshot.authoritativeSchedulingOutcome == nil)

        await gate.open()
        _ = await task.value
    }

    private func makeLifecycle(
        recorder: LifecycleRecorder,
        gate: LifecycleGate?,
        outcome: Outcome
    ) -> BackgroundRefreshLifecycle {
        BackgroundRefreshLifecycle(
            beginRun: { Self.transientRun() },
            scheduleFallback: {
                await recorder.recordAcceptedFallback()
                return .submitted
            },
            runOrchestration: { _ in
                await recorder.recordOrchestrationStart()
                if let gate {
                    await gate.wait()
                }
                return outcome
            },
            scheduleAuthoritative: { nextRun in
                await recorder.recordAuthoritative(nextRun)
                return .submitted
            }
        )
    }

    private func outcome(next: Date, result: Outcome.BackgroundResult) -> Outcome {
        .init(next: next, result: result, didNotify: false, feedsChanged: [])
    }

    private static func transientRun() -> BackgroundRefreshRun {
        .init(runId: UUID().uuidString, startedAt: .now, schedulingRecorder: { _, _ in })
    }
}

@MainActor
private func backgroundRun(id: String, in container: ModelContainer) throws -> LifecycleRunState? {
    let descriptor = FetchDescriptor<BgRunSnapshot>(predicate: #Predicate { $0.runId == id })
    return try ModelContext(container).fetch(descriptor).first.map(LifecycleRunState.init)
}

private func waitForBackgroundRun(
    id: String,
    in container: ModelContainer,
    timeout: Duration = .seconds(1),
    interval: Duration = .milliseconds(10),
    matching predicate: @escaping @Sendable (LifecycleRunState) -> Bool
) async throws -> LifecycleRunState? {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if let snapshot = try await backgroundRun(id: id, in: container),
           predicate(snapshot) {
            return snapshot
        }
        try? await Task.sleep(for: interval)
    }
    guard let snapshot = try await backgroundRun(id: id, in: container),
          predicate(snapshot) else {
        return nil
    }
    return snapshot
}

private struct LifecycleRunState: Sendable {
    let fallbackSchedulingOutcome: BgSchedulingOutcome?
    let authoritativeSchedulingOutcome: BgSchedulingOutcome?

    init(_ snapshot: BgRunSnapshot) {
        fallbackSchedulingOutcome = snapshot.fallbackSchedulingOutcome
        authoritativeSchedulingOutcome = snapshot.authoritativeSchedulingOutcome
    }
}

private actor LifecycleRecorder {
    private var recordedEvents: [String] = []
    private var recordedAuthoritativeRuns: [Date] = []
    private var acceptedFallbackCount = 0
    private var orchestrationStartContinuation: CheckedContinuation<Void, Never>?

    func recordAcceptedFallback() {
        acceptedFallbackCount += 1
        recordedEvents.append("fallback-complete")
    }

    func recordOrchestrationStart() {
        recordedEvents.append("orchestration-start")
        orchestrationStartContinuation?.resume()
        orchestrationStartContinuation = nil
    }

    func recordAuthoritative(_ nextRun: Date) {
        recordedAuthoritativeRuns.append(nextRun)
        recordedEvents.append("authoritative-\(nextRun.timeIntervalSince1970)")
    }

    func waitForOrchestrationStart() async {
        if recordedEvents.contains("orchestration-start") {
            return
        }
        await withCheckedContinuation { orchestrationStartContinuation = $0 }
    }

    func events() -> [String] {
        recordedEvents
    }

    func authoritativeRuns() -> [Date] {
        recordedAuthoritativeRuns
    }

    func fallbackAttempts() -> Int {
        recordedEvents.filter { $0 == "fallback-complete" }.count
    }

    func acceptedFallbacks() -> Int {
        acceptedFallbackCount
    }
}

private actor LifecycleGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private actor RecordingSchedulingBackend: BackgroundSchedulingBackend {
    enum SubmissionResult: Sendable, Equatable {
        case success
        case failure
    }

    enum Operation: Sendable, Equatable {
        case cancel
        case submit(Date)
    }

    private let pending: BackgroundScheduler.PendingRequest
    private var submissionResults: [SubmissionResult]
    private var recordedOperations: [Operation] = []

    init(pending: BackgroundScheduler.PendingRequest, submissionResults: [SubmissionResult]) {
        self.pending = pending
        self.submissionResults = submissionResults
    }

    func pendingRequest(for id: String) async -> BackgroundScheduler.PendingRequest {
        pending
    }

    func cancel(taskRequestWithIdentifier id: String) async {
        recordedOperations.append(.cancel)
    }

    func submit(identifier: String, earliestBeginDate: Date) async throws {
        recordedOperations.append(.submit(earliestBeginDate))
        let result = submissionResults.removeFirst()
        if result == .failure {
            throw SubmissionError.rejected
        }
    }

    func operations() -> [Operation] {
        recordedOperations
    }

    func submittedRuns() -> [Date] {
        recordedOperations.compactMap { operation in
            guard case .submit(let date) = operation else {
                return nil
            }
            return date
        }
    }

    private enum SubmissionError: Error {
        case rejected
    }
}
