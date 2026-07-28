import Foundation
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
            scheduleFallback: {
                await scheduler.ensureScheduled(using: RefreshPolicy(), now: .distantPast)
            },
            runOrchestration: {
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

    private func makeLifecycle(
        recorder: LifecycleRecorder,
        gate: LifecycleGate?,
        outcome: Outcome
    ) -> BackgroundRefreshLifecycle {
        BackgroundRefreshLifecycle(
            scheduleFallback: {
                await recorder.recordAcceptedFallback()
                return .submitted
            },
            runOrchestration: {
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
