import Foundation
import Testing
@testable import SkyAware

private enum HTTPStubResult {
    case response(status: Int, headers: [String: String], body: Data?)
    case error(URLError)
}

private final class HTTPTestURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubsByURL: [String: [HTTPStubResult]] = [:]
    nonisolated(unsafe) private static var requestTimeoutsByURL: [String: [TimeInterval]] = [:]

    static func reset() {
        lock.lock()
        stubsByURL = [:]
        requestTimeoutsByURL = [:]
        lock.unlock()
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
        }
    }

    override func stopLoading() {}

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
        defer { lock.unlock() }
        requestTimeoutsByURL[url.absoluteString, default: []].append(timeout)
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
        )
    ) -> URLSessionHTTPClient {
        let foregroundSession = makeSession(cache: cache)
        let backgroundSession = makeSession(cache: cache)
        return URLSessionHTTPClient(
            foregroundPolicy: foregroundPolicy,
            backgroundPolicy: backgroundPolicy,
            urlCache: cache,
            foregroundSession: foregroundSession,
            backgroundSession: backgroundSession,
            sleepFor: { _ in },
            now: Date.init
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
