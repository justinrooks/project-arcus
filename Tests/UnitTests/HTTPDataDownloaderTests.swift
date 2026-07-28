import Foundation
import Synchronization
import Testing
@testable import SkyAware

private enum HTTPStubResult {
    case response(status: Int, headers: [String: String], body: Data?)
    case error(URLError)
    case pending
}

private final class HTTPTestURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubsByURL: [String: [HTTPStubResult]] = [:]
    nonisolated(unsafe) private static var requestTimeoutsByURL: [String: [TimeInterval]] = [:]
    nonisolated(unsafe) private static var stoppedURLs: Set<String> = []
    nonisolated(unsafe) private static var requestStartContinuations: [String: [CheckedContinuation<Void, Never>]] = [:]

    static func reset() {
        lock.lock()
        stubsByURL = [:]
        requestTimeoutsByURL = [:]
        stoppedURLs = []
        let continuations = requestStartContinuations.values.flatMap { $0 }
        requestStartContinuations = [:]
        lock.unlock()
        continuations.forEach { $0.resume() }
    }

    static func setStubs(_ stubs: [URL: [HTTPStubResult]]) {
        lock.lock()
        stubsByURL = Dictionary(
            uniqueKeysWithValues: stubs.map { ($0.key.absoluteString, $0.value) }
        )
        lock.unlock()
    }

    static func requestTimeouts(for url: URL) -> [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return requestTimeoutsByURL[url.absoluteString] ?? []
    }

    static func didStopLoading(for url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stoppedURLs.contains(url.absoluteString)
    }

    static func waitForRequest(for url: URL) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if requestTimeoutsByURL[url.absoluteString] != nil {
                lock.unlock()
                continuation.resume()
                return
            }
            requestStartContinuations[url.absoluteString, default: []].append(continuation)
            lock.unlock()
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "example.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.record(timeout: request.timeoutInterval, for: url)

        guard let next = Self.popStub(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch next {
        case .response(let status, let headers, let body):
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            if let body {
                client?.urlProtocol(self, didLoad: body)
            }
            client?.urlProtocolDidFinishLoading(self)
        case .error(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .pending:
            break
        }
    }

    override func stopLoading() {
        guard let url = request.url else { return }
        Self.recordStopped(url)
    }

    private static func popStub(for url: URL) -> HTTPStubResult? {
        lock.lock()
        defer { lock.unlock() }
        let key = url.absoluteString
        guard var queue = stubsByURL[key], !queue.isEmpty else { return nil }
        let item = queue.removeFirst()
        stubsByURL[key] = queue
        return item
    }

    private static func record(timeout: TimeInterval, for url: URL) {
        lock.lock()
        requestTimeoutsByURL[url.absoluteString, default: []].append(timeout)
        let continuations = requestStartContinuations.removeValue(forKey: url.absoluteString) ?? []
        lock.unlock()
        continuations.forEach { $0.resume() }
    }

    private static func recordStopped(_ url: URL) {
        lock.lock()
        stoppedURLs.insert(url.absoluteString)
        lock.unlock()
    }
}

private actor HTTPTestDeadlineGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        let continuations = continuations
        self.continuations = []
        continuations.forEach { $0.resume() }
    }
}

@Suite("HTTPDataDownloader", .serialized)
struct HTTPDataDownloaderTests {
    @Test("429 with Retry-After retries and then succeeds")
    func retries429ThenSucceeds() async throws {
        let url = URL(string: "https://example.test/retry-429")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            url: [
                .response(status: 429, headers: ["Retry-After": "0"], body: Data("slow".utf8)),
                .response(status: 200, headers: [:], body: Data("ok".utf8))
            ]
        ])

        let client = makeDownloader()
        let response = try await client.get(url, headers: [:])

        #expect(response.status == 200)
        #expect(response.source == .live)
        #expect(response.data == Data("ok".utf8))
    }

    @Test("503 retries can exhaust and serve cache fallback")
    func retries503ThenUsesCacheFallback() async throws {
        let url = URL(string: "https://example.test/retry-503")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            url: [
                .response(status: 503, headers: ["Retry-After": "0"], body: nil),
                .response(status: 503, headers: ["Retry-After": "0"], body: nil)
            ]
        ])

        let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 1_000_000, diskPath: nil)
        storeCachedBody(Data("cached-503".utf8), for: url, cache: cache)
        let client = makeDownloader(cache: cache)

        let response = try await client.get(url, headers: [:])
        #expect(response.source == .cacheFallback)
        #expect(response.data == Data("cached-503".utf8))
    }

    @Test("304 uses cached body and marks revalidated source")
    func notModifiedUsesCachedBody() async throws {
        let url = URL(string: "https://example.test/not-modified")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            url: [
                .response(status: 304, headers: [:], body: nil)
            ]
        ])

        let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 1_000_000, diskPath: nil)
        storeCachedBody(Data("cached-304".utf8), for: url, cache: cache)
        let client = makeDownloader(cache: cache)

        let response = try await client.get(url, headers: [:])
        #expect(response.status == 304)
        #expect(response.source == .cacheRevalidated304)
        #expect(response.data == Data("cached-304".utf8))
    }

    @Test("Transient transport failure can use cache fallback")
    func transientFailureUsesCacheFallbackWhenAllowed() async throws {
        let url = URL(string: "https://example.test/transient-fallback")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            url: [
                .error(URLError(.timedOut))
            ]
        ])

        let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 1_000_000, diskPath: nil)
        storeCachedBody(Data("cached-timeout".utf8), for: url, cache: cache)
        let policy = HTTPRequestPolicy(
            requestTimeout: 5,
            resourceTimeout: 5,
            retryDelays: [],
            retryableStatusCodes: [429, 503],
            allowCacheFallback: true
        )
        let client = makeDownloader(cache: cache, foregroundPolicy: policy, backgroundPolicy: policy)

        let response = try await client.get(url, headers: [:])
        #expect(response.source == .cacheFallback)
        #expect(response.data == Data("cached-timeout".utf8))
    }

    @Test("Transient transport failure throws when cache fallback disabled")
    func transientFailureThrowsWhenCacheFallbackDisabled() async throws {
        let url = URL(string: "https://example.test/transient-no-fallback")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            url: [
                .error(URLError(.timedOut))
            ]
        ])

        let policy = HTTPRequestPolicy(
            requestTimeout: 5,
            resourceTimeout: 5,
            retryDelays: [],
            retryableStatusCodes: [429, 503],
            allowCacheFallback: false
        )
        let client = makeDownloader(foregroundPolicy: policy, backgroundPolicy: policy)

        do {
            _ = try await client.get(url, headers: [:])
            #expect(Bool(false), "Expected URLError(.timedOut)")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("Execution mode selects foreground/background request policy")
    func executionModeSelectsPolicy() async throws {
        let foregroundURL = URL(string: "https://example.test/profile-foreground")!
        let backgroundURL = URL(string: "https://example.test/profile-background")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            foregroundURL: [
                .response(status: 200, headers: [:], body: Data("fg".utf8))
            ],
            backgroundURL: [
                .response(status: 200, headers: [:], body: Data("bg".utf8))
            ]
        ])

        let foregroundPolicy = HTTPRequestPolicy(
            requestTimeout: 3,
            resourceTimeout: 6,
            retryDelays: [],
            retryableStatusCodes: [429, 503],
            allowCacheFallback: true
        )
        let backgroundPolicy = HTTPRequestPolicy(
            requestTimeout: 22,
            resourceTimeout: 30,
            retryDelays: [],
            retryableStatusCodes: [429, 503],
            allowCacheFallback: true
        )
        let client = makeDownloader(foregroundPolicy: foregroundPolicy, backgroundPolicy: backgroundPolicy)

        try await HTTPExecutionMode.$current.withValue(.foreground) {
            _ = try await client.get(foregroundURL, headers: [:])
        }
        try await HTTPExecutionMode.$current.withValue(.background) {
            _ = try await client.get(backgroundURL, headers: [:])
        }

        let foregroundTimeout = HTTPTestURLProtocol.requestTimeouts(for: foregroundURL).first
        let backgroundTimeout = HTTPTestURLProtocol.requestTimeouts(for: backgroundURL).first

        #expect(foregroundTimeout == foregroundPolicy.requestTimeout)
        #expect(backgroundTimeout == backgroundPolicy.requestTimeout)
    }

    @Test("Budgeted background request timeout is capped to remaining work")
    func budgetedBackgroundRequestCapsTimeout() async throws {
        let url = URL(string: "https://example.test/budget-timeout")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.response(status: 200, headers: [:], body: nil)]])

        let clock = ContinuousClock()
        let start = clock.now
        let currentInstant = Mutex(start)
        let client = makeDownloader(
            backgroundPolicy: testPolicy(requestTimeout: 15, retryDelays: []),
            budgetNow: { currentInstant.withLock { $0 } }
        )

        try await withBackgroundBudget(workDuration: .seconds(3), start: start) {
            _ = try await client.get(url, headers: [:])
        }

        #expect(HTTPTestURLProtocol.requestTimeouts(for: url) == [3])
    }

    @Test("Budgeted background request refuses an expired work deadline")
    func budgetedBackgroundRequestRefusesExpiredDeadline() async {
        let url = URL(string: "https://example.test/budget-expired")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.response(status: 200, headers: [:], body: nil)]])

        let clock = ContinuousClock()
        let start = clock.now
        let client = makeDownloader(budgetNow: { start })

        await #expect(throws: CancellationError.self) {
            try await withBackgroundBudget(workDuration: .zero, start: start) {
                _ = try await client.get(url, headers: [:])
            }
        }
        #expect(HTTPTestURLProtocol.requestTimeouts(for: url).isEmpty)
    }

    @Test("Budget deadline cancels an in-flight delayed transfer")
    func budgetedBackgroundRequestCancelsDelayedTransferAtDeadline() async {
        let url = URL(string: "https://example.test/budget-delayed-transfer")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.pending]])

        let clock = ContinuousClock()
        let start = clock.now
        let deadlineGate = HTTPTestDeadlineGate()
        let client = makeDownloader(
            backgroundPolicy: testPolicy(requestTimeout: 15, retryDelays: []),
            budgetNow: { start },
            sleepForDeadline: { _ in await deadlineGate.wait() }
        )

        let requestTask = Task {
            try await withBackgroundBudget(workDuration: .seconds(10), start: start) {
                _ = try await client.get(url, headers: [:])
            }
        }
        await HTTPTestURLProtocol.waitForRequest(for: url)
        await deadlineGate.open()
        await #expect(throws: CancellationError.self) {
            try await requestTask.value
        }
        #expect(HTTPTestURLProtocol.didStopLoading(for: url))
    }

    @Test("Budgeted transient retry runs only while its delay fits")
    func budgetedTransientRetryRunsWhileAdmitted() async throws {
        let url = URL(string: "https://example.test/budget-transient-retry")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([
            url: [
                .error(URLError(.timedOut)),
                .response(status: 200, headers: [:], body: nil)
            ]
        ])

        let clock = ContinuousClock()
        let start = clock.now
        let currentInstant = Mutex(start)
        let sleeps = Mutex<[TimeInterval]>([])
        let client = makeDownloader(
            backgroundPolicy: testPolicy(requestTimeout: 15, retryDelays: [5]),
            sleepFor: { delay in
                sleeps.withLock { $0.append(delay) }
                currentInstant.withLock { $0 += .seconds(delay) }
            },
            budgetNow: { currentInstant.withLock { $0 } }
        )

        try await withBackgroundBudget(workDuration: .seconds(10), start: start) {
            _ = try await client.get(url, headers: [:])
        }

        #expect(sleeps.withLock { $0 } == [5])
        #expect(HTTPTestURLProtocol.requestTimeouts(for: url).count == 2)
    }

    @Test("Budgeted 429 Retry-After refuses retry and serves eligible cache")
    func budgeted429RetryAfterUsesCacheWhenRetryDoesNotFit() async throws {
        try await assertBudgetedRetryAfterFallsBackToCache(status: 429)
    }

    @Test("Budgeted 503 Retry-After refuses retry and serves eligible cache")
    func budgeted503RetryAfterUsesCacheWhenRetryDoesNotFit() async throws {
        try await assertBudgetedRetryAfterFallsBackToCache(status: 503)
    }

    @Test("Budgeted retry exhaustion without cache is cancellation")
    func budgetedRetryExhaustionWithoutCacheIsCancellation() async {
        let url = URL(string: "https://example.test/budget-no-cache")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.response(status: 503, headers: ["Retry-After": "5"], body: nil)]])

        let clock = ContinuousClock()
        let start = clock.now
        let client = makeDownloader(
            backgroundPolicy: testPolicy(requestTimeout: 15, retryDelays: [5]),
            budgetNow: { start }
        )

        await #expect(throws: CancellationError.self) {
            try await withBackgroundBudget(workDuration: .seconds(3), start: start) {
                _ = try await client.get(url, headers: [:])
            }
        }
    }

    @Test("Cancellation during a budgeted retry wait remains cancellation")
    func cancellationDuringBudgetedRetryWaitRemainsCancellation() async {
        let url = URL(string: "https://example.test/budget-cancel-wait")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.response(status: 429, headers: ["Retry-After": "1"], body: nil)]])

        let clock = ContinuousClock()
        let start = clock.now
        let client = makeDownloader(
            backgroundPolicy: testPolicy(requestTimeout: 15, retryDelays: [1]),
            sleepFor: { _ in throw CancellationError() },
            budgetNow: { start }
        )

        await #expect(throws: CancellationError.self) {
            try await withBackgroundBudget(workDuration: .seconds(10), start: start) {
                _ = try await client.get(url, headers: [:])
            }
        }
    }

    @Test("Foreground policy ignores a surrounding background budget")
    func foregroundPolicyIgnoresBackgroundBudget() async throws {
        let url = URL(string: "https://example.test/foreground-budget")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.response(status: 200, headers: [:], body: nil)]])

        let clock = ContinuousClock()
        let start = clock.now
        let client = makeDownloader(
            foregroundPolicy: testPolicy(requestTimeout: 9, retryDelays: []),
            budgetNow: { start }
        )

        try await BackgroundRefreshExecutionContext.$current.withValue(.init(budget: budget(workDuration: .seconds(1), start: start))) {
            try await HTTPExecutionMode.$current.withValue(.foreground) {
                _ = try await client.get(url, headers: [:])
            }
        }

        #expect(HTTPTestURLProtocol.requestTimeouts(for: url) == [9])
    }

    private func makeDownloader(
        cache: URLCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 1_000_000, diskPath: nil),
        foregroundPolicy: HTTPRequestPolicy = HTTPRequestPolicy(
            requestTimeout: 5,
            resourceTimeout: 8,
            retryDelays: [0],
            retryableStatusCodes: [429, 503],
            allowCacheFallback: true
        ),
        backgroundPolicy: HTTPRequestPolicy = HTTPRequestPolicy(
            requestTimeout: 15,
            resourceTimeout: 25,
            retryDelays: [0],
            retryableStatusCodes: [429, 503],
            allowCacheFallback: true
        ),
        sleepFor: @escaping @Sendable (TimeInterval) async throws -> Void = { _ in },
        budgetNow: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now },
        sleepForDeadline: @escaping @Sendable (Duration) async throws -> Void = URLSessionHTTPClient.defaultDeadlineSleep
    ) -> URLSessionHTTPClient {
        let foregroundSession = makeSession(cache: cache)
        let backgroundSession = makeSession(cache: cache)
        return URLSessionHTTPClient(
            foregroundPolicy: foregroundPolicy,
            backgroundPolicy: backgroundPolicy,
            urlCache: cache,
            foregroundSession: foregroundSession,
            backgroundSession: backgroundSession,
            sleepFor: sleepFor,
            now: Date.init,
            budgetNow: budgetNow,
            sleepForDeadline: sleepForDeadline
        )
    }

    private func assertBudgetedRetryAfterFallsBackToCache(status: Int) async throws {
        let url = URL(string: "https://example.test/budget-retry-after-\(status)")!
        HTTPTestURLProtocol.reset()
        HTTPTestURLProtocol.setStubs([url: [.response(status: status, headers: ["Retry-After": "5"], body: nil)]])

        let cache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 1_000_000, diskPath: nil)
        storeCachedBody(Data("cached-\(status)".utf8), for: url, cache: cache)
        let clock = ContinuousClock()
        let start = clock.now
        let sleeps = Mutex<[TimeInterval]>([])
        let client = makeDownloader(
            cache: cache,
            backgroundPolicy: testPolicy(requestTimeout: 15, retryDelays: [5]),
            sleepFor: { delay in sleeps.withLock { $0.append(delay) } },
            budgetNow: { start }
        )

        let response = try await withBackgroundBudget(workDuration: .seconds(3), start: start) {
            try await client.get(url, headers: [:])
        }

        #expect(response.source == .cacheFallback)
        #expect(response.data == Data("cached-\(status)".utf8))
        #expect(sleeps.withLock { $0 }.isEmpty)
    }

    private func withBackgroundBudget<Result: Sendable>(
        workDuration: Duration,
        start: ContinuousClock.Instant,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await BackgroundRefreshExecutionContext.$current.withValue(.init(budget: budget(workDuration: workDuration, start: start))) {
            try await HTTPExecutionMode.$current.withValue(.background, operation: operation)
        }
    }

    private func budget(workDuration: Duration, start: ContinuousClock.Instant) -> BackgroundRefreshBudget {
        BackgroundRefreshBudget(
            start: start,
            completionDeadline: start + workDuration,
            finalizationReserve: .zero
        )
    }

    private func testPolicy(requestTimeout: TimeInterval, retryDelays: [TimeInterval]) -> HTTPRequestPolicy {
        HTTPRequestPolicy(
            requestTimeout: requestTimeout,
            resourceTimeout: 30,
            retryDelays: retryDelays,
            retryableStatusCodes: [429, 503],
            allowCacheFallback: true,
            jitterMultiplierRange: 1...1
        )
    }

    private func makeSession(cache: URLCache) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HTTPTestURLProtocol.self]
        config.urlCache = cache
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    private func storeCachedBody(_ body: Data, for url: URL, cache: URLCache) {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Cache-Control": "max-age=3600"])!
        cache.storeCachedResponse(CachedURLResponse(response: response, data: body), for: request)
    }
}
