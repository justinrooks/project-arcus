//
//  HTTPDataDownloader.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

public enum HTTPExecutionMode: Sendable {
    case foreground
    case background

    @TaskLocal public static var current: HTTPExecutionMode = .background
}

public struct HTTPRequestPolicy: Sendable {
    public let requestTimeout: TimeInterval
    public let resourceTimeout: TimeInterval
    public let retryDelays: [TimeInterval]
    public let retryableStatusCodes: Set<Int>
    public let allowCacheFallback: Bool
    public let maxRetryAfterSeconds: Int
    public let jitterMultiplierRange: ClosedRange<Double>

    public init(
        requestTimeout: TimeInterval,
        resourceTimeout: TimeInterval,
        retryDelays: [TimeInterval],
        retryableStatusCodes: Set<Int> = [429, 503],
        allowCacheFallback: Bool = true,
        maxRetryAfterSeconds: Int = 120,
        jitterMultiplierRange: ClosedRange<Double> = 0.90...1.10
    ) {
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.retryDelays = retryDelays
        self.retryableStatusCodes = retryableStatusCodes
        self.allowCacheFallback = allowCacheFallback
        self.maxRetryAfterSeconds = maxRetryAfterSeconds
        self.jitterMultiplierRange = jitterMultiplierRange
    }

    public static let foreground = HTTPRequestPolicy(
        requestTimeout: 10,
        resourceTimeout: 15,
        retryDelays: [0.75, 1.5],
        retryableStatusCodes: [429, 503],
        allowCacheFallback: true,
        maxRetryAfterSeconds: 45,
        jitterMultiplierRange: 0.85...1.05
    )

    public static let background = HTTPRequestPolicy(
        requestTimeout: 15,
        resourceTimeout: 25,
        retryDelays: [5, 10, 15],
        retryableStatusCodes: [429, 503],
        allowCacheFallback: true,
        maxRetryAfterSeconds: 180,
        jitterMultiplierRange: 0.90...1.10
    )
}

public enum HTTPStatusClassification: Sendable, Equatable {
    case success
    case notModified
    case rateLimited(retryAfterSeconds: Int?)
    case serviceUnavailable(retryAfterSeconds: Int?)
    case failure(status: Int)
}

public enum HTTPRetryAfterParser {
    public static func seconds(from value: String?, now: Date = .now) -> Int? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if let seconds = Int(value) {
            return max(0, seconds)
        }

        let retryAt = value.fromRFC1123String() ?? value.fromRFC822()
        guard let retryAt else { return nil }

        return max(0, Int(ceil(retryAt.timeIntervalSince(now))))
    }
}

public enum HTTPRequestHeaders {
    public static func userAgent(bundle: Bundle = .main, fallbackName: String = "SkyAware") -> String {
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? fallbackName
        let bundleID = bundle.bundleIdentifier ?? "skyaware.app"
        return "\(appName)/\(bundle.appVersion) (\(bundleID); build:\(bundle.buildNumber))"
    }

    public static func arcus(bundle: Bundle = .main) -> [String: String] {
        [
            "User-Agent": userAgent(bundle: bundle),
             "Accept": "application/json"//,
//            "If-None-Match": "*"
        ]
    }
    
    public static func nws(bundle: Bundle = .main) -> [String: String] {
        [
            "User-Agent": userAgent(bundle: bundle),
            "Accept": "application/geo+json"
        ]
    }

    public static func spcRss(bundle: Bundle = .main) -> [String: String] {
        [
            "User-Agent": userAgent(bundle: bundle),
            "Accept": "application/rss+xml, application/xml;q=0.9, */*;q=0.8"
        ]
    }

    public static func spcGeoJSON(bundle: Bundle = .main) -> [String: String] {
        [
            "User-Agent": userAgent(bundle: bundle),
            "Accept": "application/geo+json, application/json;q=0.9, */*;q=0.8"
        ]
    }
}

public struct HTTPResponse {
    public enum Source: Sendable, Equatable, CustomStringConvertible {
        case live
        case cacheFallback
        case cacheRevalidated304

        public var description: String {
            switch self {
            case .live:
                "live"
            case .cacheFallback:
                "cacheFallback"
            case .cacheRevalidated304:
                "cacheRevalidated304"
            }
        }
    }

    public let status: Int
    public let headers: [String: String]
    public let data: Data?
    public let source: Source

    public init(
        status: Int,
        headers: [String: String],
        data: Data?,
        source: Source = .live
    ) {
        self.status = status
        self.headers = headers
        self.data = data
        self.source = source
    }

    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    public func classifyStatus(now: Date = .now) -> HTTPStatusClassification {
        guard !(200...299).contains(status) else { return .success }
        if status == 304 { return .notModified }

        let retryAfter = HTTPRetryAfterParser.seconds(from: header("Retry-After"), now: now)
        switch status {
        case 429:
            return .rateLimited(retryAfterSeconds: retryAfter)
        case 503:
            return .serviceUnavailable(retryAfterSeconds: retryAfter)
        default:
            return .failure(status: status)
        }
    }
}

public protocol HTTPResponseObserving: Sendable {
    func didReceive(response: HTTPURLResponse, for requestURL: URL) async
}

public struct NoOpHTTPResponseObserver: HTTPResponseObserving {
    public init() {}
    public func didReceive(response: HTTPURLResponse, for requestURL: URL) async {}
}

public actor LastGlobalSuccessHTTPObserver: HTTPResponseObserving {
    private let store: UserDefaults?
    private let key: String

    public init(
        store: UserDefaults? = UserDefaults(suiteName: "com.justinrooks.skyaware"),
        key: String = "lastGlobalSuccessAt"
    ) {
        self.store = store
        self.key = key
    }

    public func didReceive(response: HTTPURLResponse, for requestURL: URL) async {
        guard (200...299).contains(response.statusCode) else { return }
        guard let lastModified = response.value(forHTTPHeaderField: "Last-Modified")?.fromRFC1123String() else { return }
        store?.set(lastModified.timeIntervalSince1970, forKey: key)
    }
}

public protocol HTTPClient: Sendable {
    func get (_ url: URL, headers: [String: String]) async throws -> HTTPResponse
    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse
    func clearCache()
}

public final class URLSessionHTTPClient: HTTPClient {
    private let logger = Logger.networkDownloader
    private let observer: any HTTPResponseObserving
    private let foregroundPolicy: HTTPRequestPolicy
    private let backgroundPolicy: HTTPRequestPolicy
    private let foregroundSession: URLSession
    private let backgroundSession: URLSession
    private let urlCache: URLCache
    private let sleepFor: @Sendable (TimeInterval) async throws -> Void
    private let now: @Sendable () -> Date

    public init(
        observer: any HTTPResponseObserving = NoOpHTTPResponseObserver(),
        foregroundPolicy: HTTPRequestPolicy = .foreground,
        backgroundPolicy: HTTPRequestPolicy = .background,
        urlCache: URLCache = .shared,
        foregroundSession: URLSession? = nil,
        backgroundSession: URLSession? = nil,
        sleepFor: @escaping @Sendable (TimeInterval) async throws -> Void = URLSessionHTTPClient.defaultSleep,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.observer = observer
        self.foregroundPolicy = foregroundPolicy
        self.backgroundPolicy = backgroundPolicy
        self.urlCache = urlCache
        self.foregroundSession = foregroundSession ?? Self.makeSession(policy: foregroundPolicy, cache: urlCache)
        self.backgroundSession = backgroundSession ?? Self.makeSession(policy: backgroundPolicy, cache: urlCache)
        self.sleepFor = sleepFor
        self.now = now
    }

    public func get(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request(url: url, method: "GET", headers: headers, body: nil)
    }

    public func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
        try await request(url: url, method: "POST", headers: headers, body: body)
    }

    public func clearCache() {
        urlCache.removeAllCachedResponses()
    }

    func getCachedResponse(for url: URL, timeout: TimeInterval) -> CachedURLResponse? {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataDontLoad, timeoutInterval: timeout)
        return urlCache.cachedResponse(for: request)
    }

    private static func makeSession(policy: HTTPRequestPolicy, cache: URLCache) -> URLSession {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = policy.requestTimeout
        config.timeoutIntervalForResource = policy.resourceTimeout
        config.urlCache = cache
        return URLSession(configuration: config)
    }

    public static func defaultSleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        let nanos = UInt64((seconds * 1_000_000_000).rounded())
        try await Task.sleep(nanoseconds: nanos)
    }

    private func request(url: URL, method: String, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        let mode = HTTPExecutionMode.current
        let policy = policy(for: mode)
        let session = session(for: mode)
        let maxAttempts = policy.retryDelays.count + 1

        for attempt in 0..<maxAttempts {
            try Task.checkCancellation()
            do {
                var req = URLRequest(url: url)
                req.httpMethod = method
                req.httpBody = body
                req.timeoutInterval = policy.requestTimeout

                headers.forEach { header in
                    req.setValue(
                        header.value,
                        forHTTPHeaderField: header.key
                    )
                }

                let (data, response) = try await session.data(for: req, delegate: nil)

                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                await observer.didReceive(response: http, for: url)

                let responseHeaders = normalizedHeaders(from: http.allHeaderFields)
                let liveResponse = HTTPResponse(status: http.statusCode,
                                                headers: responseHeaders,
                                                data: data.isEmpty ? nil : data,
                                                source: .live)
                switch liveResponse.classifyStatus(now: now()) {
                case .success:
                    return liveResponse
                case .notModified:
                    if let cached = getCachedResponse(for: url, timeout: policy.requestTimeout) {
                        logger.notice("Using cache revalidation fallback (304) for host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public)")
                        return HTTPResponse(status: liveResponse.status,
                                            headers: responseHeaders,
                                            data: cached.data.isEmpty ? nil : cached.data,
                                            source: .cacheRevalidated304)
                    }

                    logger.error("Received 304 without cached body for host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public)")
                    throw URLError(.badServerResponse)
                case .rateLimited(let retryAfter), .serviceUnavailable(let retryAfter):
                    if policy.retryableStatusCodes.contains(liveResponse.status) {
                        if let wait = retryInterval(
                            attempt: attempt,
                            retryAfterSeconds: retryAfter,
                            policy: policy
                        ) {
                            logger.debug("Retrying HTTP status \(liveResponse.status, privacy: .public) in \(wait, privacy: .public)s host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public)")
                            try await sleepFor(wait)
                            continue
                        }
                    }

                    if let fallback = cacheFallbackResponse(
                        method: method,
                        url: url,
                        policy: policy,
                        reason: "status_\(liveResponse.status)"
                    ) {
                        return fallback
                    }

                    return liveResponse
                case .failure:
                    return liveResponse
                }
            } catch {
                if error is CancellationError || Task.isCancelled {
                    logger.debug("Request cancelled for host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public)")
                    throw CancellationError()
                }

                if isTransient(error) {
                    if let wait = retryInterval(attempt: attempt, retryAfterSeconds: nil, policy: policy) {
                        logger.debug("Retrying transient transport failure in \(wait, privacy: .public)s host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public)")
                        try await sleepFor(wait)
                        continue
                    }

                    if let fallback = cacheFallbackResponse(
                        method: method,
                        url: url,
                        policy: policy,
                        reason: "transport_error"
                    ) {
                        return fallback
                    }

                    logger.error("Transient request error exhausted retries host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public): \(error, privacy: .public)")
                    throw error
                }

                logger.error("Non transient request error. Fatal: \(error, privacy: .public)")
                throw error
            }
        }

        // Defensive fallback; loop should either return or throw earlier.
        throw URLError(.cannotLoadFromNetwork)
    }

    private func session(for mode: HTTPExecutionMode) -> URLSession {
        switch mode {
        case .foreground:
            foregroundSession
        case .background:
            backgroundSession
        }
    }

    private func policy(for mode: HTTPExecutionMode) -> HTTPRequestPolicy {
        switch mode {
        case .foreground:
            foregroundPolicy
        case .background:
            backgroundPolicy
        }
    }

    private func retryInterval(
        attempt: Int,
        retryAfterSeconds: Int?,
        policy: HTTPRequestPolicy
    ) -> TimeInterval? {
        guard attempt < policy.retryDelays.count else { return nil }

        let baseDelay = retryAfterSeconds.map { Double(min($0, policy.maxRetryAfterSeconds)) } ?? policy.retryDelays[attempt]
        let jitter = Double.random(in: policy.jitterMultiplierRange)
        let jittered = max(0, min(baseDelay * jitter, Double(policy.maxRetryAfterSeconds)))
        return jittered
    }

    private func cacheFallbackResponse(
        method: String,
        url: URL,
        policy: HTTPRequestPolicy,
        reason: String
    ) -> HTTPResponse? {
        guard method == "GET", policy.allowCacheFallback else { return nil }
        guard let cached = getCachedResponse(for: url, timeout: policy.requestTimeout) else { return nil }

        let headers: [String: String]
        let status: Int
        if let cachedHttp = cached.response as? HTTPURLResponse {
            headers = normalizedHeaders(from: cachedHttp.allHeaderFields)
            status = cachedHttp.statusCode
        } else {
            headers = [:]
            status = 200
        }

        logger.notice("Serving cached HTTP fallback host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public) reason=\(reason, privacy: .public)")

        return HTTPResponse(status: status,
                            headers: headers,
                            data: cached.data.isEmpty ? nil : cached.data,
                            source: .cacheFallback)
    }

    private func normalizedHeaders(from raw: [AnyHashable: Any]) -> [String: String] {
        var output: [String: String] = [:]
        output.reserveCapacity(raw.count)

        for (key, value) in raw {
            let headerName = String(describing: key)
            let headerValue = String(describing: value)
            output[headerName] = headerValue
        }

        return output
    }
    
    private func isTransient(_ error: Error) -> Bool {
        let e = error as? URLError
        switch e?.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost,
             .networkConnectionLost, .dnsLookupFailed, .resourceUnavailable,
             .notConnectedToInternet, .internationalRoamingOff,
             .callIsActive, .dataNotAllowed, .requestBodyStreamExhausted:
            return true
        default:
            return false
        }
    }
}
