import Foundation
import Testing
@testable import SkyAware

@Suite("Log Viewer Cancellation")
struct LogViewerCancellationTests {
    @Test("cancelling the parent cancels the detached scan")
    func cancellingParentCancelsDetachedScan() async {
        let gate = LogScanGate()
        let task = Task {
            try await runDetachedLogScan {
                await gate.markStarted()
                return try await gate.waitForCancellation()
            }
        }

        await gate.waitUntilStarted()
        task.cancel()
        await gate.waitUntilCancellation()

        do {
            _ = try await task.value
            Issue.record("A cancelled log scan returned successfully.")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error).")
        }
    }

    @Test("cancellation rejects partial scan results")
    func cancellationRejectsPartialResults() async {
        let gate = PartialResultGate()
        let task = Task {
            try await runDetachedLogScan {
                await gate.markStarted()
                return await gate.waitForPartialResult()
            }
        }

        await gate.waitUntilStarted()
        task.cancel()
        await gate.release([makeLogLine(message: "partial")])

        do {
            _ = try await task.value
            Issue.record("A cancelled log scan published partial results.")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error).")
        }
    }

    @MainActor
    @Test("an older request cannot publish or finish newer loading state")
    func olderRequestCannotPublishOrFinishNewerLoadingState() {
        var state = LogViewerLoadState()
        let firstRequest = state.startRequest()
        let firstBeganLoading = state.beginLoading(for: firstRequest)
        #expect(firstBeganLoading)
        let firstPublished = state.publish(
            [makeLogLine(message: "valid")],
            exportCache: "valid export",
            for: firstRequest
        )
        #expect(firstPublished)
        state.finish(firstRequest)

        let newerRequest = state.startRequest()
        let newerBeganLoading = state.beginLoading(for: newerRequest)
        #expect(newerBeganLoading)
        let stalePublished = state.publish(
            [makeLogLine(message: "stale")],
            exportCache: "stale export",
            for: firstRequest
        )
        #expect(!stalePublished)
        let staleFailed = state.fail(firstRequest)
        #expect(!staleFailed)
        state.finish(firstRequest)

        #expect(state.isLoading)
        #expect(state.lines.map(\.message) == ["valid"])
        #expect(state.exportCache == "valid export")

        let newerPublished = state.publish(
            [makeLogLine(message: "new")],
            exportCache: "new export",
            for: newerRequest
        )
        #expect(newerPublished)
        state.finish(newerRequest)
        #expect(!state.isLoading)
        #expect(state.lines.map(\.message) == ["new"])
        #expect(state.exportCache == "new export")
    }

    @MainActor
    @Test("rapidly superseded loads cancel stale scans and only publish the newest result")
    func rapidlySupersededLoadsCancelStaleScansAndPublishNewestResult() async {
        let gate = SupersessionScanGate()
        var state = LogViewerLoadState()

        let olderRequest = state.startRequest()
        let olderLoad = Task { @MainActor in
            guard state.beginLoading(for: olderRequest) else { return }
            defer { state.finish(olderRequest) }

            do {
                let lines = try await runDetachedLogScan {
                    return try await gate.waitForResult(for: olderRequest)
                }
                _ = state.publish(lines, exportCache: "older export", for: olderRequest)
            } catch is CancellationError {
                // Expected when the newer request supersedes this one.
            } catch {
                Issue.record("Unexpected older load error: \(error).")
            }
        }

        await gate.waitUntilReady(for: olderRequest)
        olderLoad.cancel()

        let newestRequest = state.startRequest()
        let newestLoad = Task { @MainActor in
            guard state.beginLoading(for: newestRequest) else { return }
            defer { state.finish(newestRequest) }

            do {
                let lines = try await runDetachedLogScan {
                    return try await gate.waitForResult(for: newestRequest)
                }
                _ = state.publish(lines, exportCache: "newest export", for: newestRequest)
            } catch {
                Issue.record("Unexpected newest load error: \(error).")
            }
        }

        await gate.waitUntilReady(for: newestRequest)
        await gate.waitUntilCancellation(for: olderRequest)
        _ = await olderLoad.result

        #expect(state.isLoading)
        #expect(state.lines.isEmpty)
        #expect(state.exportCache.isEmpty)

        await gate.release([makeLogLine(message: "newest")], for: newestRequest)
        _ = await newestLoad.result

        #expect(!state.isLoading)
        #expect(state.lines.map(\.message) == ["newest"])
        #expect(state.exportCache == "newest export")
    }
}

private actor LogScanGate {
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancellationObserved = false
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultContinuation: CheckedContinuation<[LogLine], Error>?

    func markStarted() {
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func waitForCancellation() async throws -> [LogLine] {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                resultContinuation = continuation
            }
        }, onCancel: {
            Task.detached { await self.observeCancellation() }
        })
    }

    func waitUntilCancellation() async {
        guard !cancellationObserved else { return }
        await withCheckedContinuation { continuation in
            cancellationWaiters.append(continuation)
        }
    }

    private func observeCancellation() {
        cancellationObserved = true
        resultContinuation?.resume(throwing: CancellationError())
        resultContinuation = nil
        let waiters = cancellationWaiters
        cancellationWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private actor PartialResultGate {
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultContinuation: CheckedContinuation<[LogLine], Never>?

    func markStarted() {
        started = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func waitForPartialResult() async -> [LogLine] {
        await withCheckedContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func release(_ result: [LogLine]) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}

private actor SupersessionScanGate {
    private var readyRequestIDs: Set<Int> = []
    private var readyWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var cancelledRequestIDs: Set<Int> = []
    private var cancellationWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var resultContinuations: [Int: CheckedContinuation<[LogLine], Error>] = [:]

    func waitForResult(for requestID: Int) async throws -> [LogLine] {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                resultContinuations[requestID] = continuation
                readyRequestIDs.insert(requestID)
                resumeReadyWaiters(for: requestID)
            }
        }, onCancel: {
            Task { await self.observeCancellation(for: requestID) }
        })
    }

    func waitUntilReady(for requestID: Int) async {
        guard !readyRequestIDs.contains(requestID) else { return }
        await withCheckedContinuation { continuation in
            readyWaiters[requestID, default: []].append(continuation)
        }
    }

    func waitUntilCancellation(for requestID: Int) async {
        guard !cancelledRequestIDs.contains(requestID) else { return }
        await withCheckedContinuation { continuation in
            cancellationWaiters[requestID, default: []].append(continuation)
        }
    }

    func release(_ result: [LogLine], for requestID: Int) {
        resultContinuations.removeValue(forKey: requestID)?.resume(returning: result)
    }

    private func observeCancellation(for requestID: Int) {
        cancelledRequestIDs.insert(requestID)
        resultContinuations.removeValue(forKey: requestID)?.resume(throwing: CancellationError())
        let waiters = cancellationWaiters.removeValue(forKey: requestID) ?? []
        waiters.forEach { $0.resume() }
    }

    private func resumeReadyWaiters(for requestID: Int) {
        let waiters = readyWaiters.removeValue(forKey: requestID) ?? []
        waiters.forEach { $0.resume() }
    }
}

private func makeLogLine(message: String) -> LogLine {
    LogLine(
        date: Date(timeIntervalSince1970: 1_750_000_000),
        level: .info,
        subsystem: "test",
        category: "cancellation",
        message: message
    )
}
