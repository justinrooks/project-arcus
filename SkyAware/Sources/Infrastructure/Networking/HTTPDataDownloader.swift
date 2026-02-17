//
//  HTTPDataDownloader.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

public enum HTTPStatusClassification: Sendable, Equatable {
    case success
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
    public let status: Int
    public let headers: [String: String]
    public let data: Data?
    
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    public func classifyStatus(now: Date = .now) -> HTTPStatusClassification {
        guard !(200...299).contains(status) else { return .success }

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
    func clearCache()
}

public final class URLSessionHTTPClient: HTTPClient {
    private let logger = Logger.networkDownloader
    private let session: URLSession
    private let delays: [UInt64] = [0, 5, 10, 15] // seconds
    private let observer: any HTTPResponseObserving
    
    public init(observer: any HTTPResponseObserving = NoOpHTTPResponseObserver()) {
        self.observer = observer
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        config.urlCache = URLCache.shared
       
        self.session = URLSession(configuration: config)
    }
    
    public func get(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request(url: url, method: "GET", headers: headers)
    }

    public func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    func getCachedData(for url: URL) -> Data? {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20.0)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request) {
            return cachedResponse.data
        }
        return nil
    }
    
    private func request(url: URL, method: String, headers: [String: String]) async throws -> HTTPResponse {
        // Try up to `delays.count` attempts. Delays array encodes backoff for retries,
        // where index+1 corresponds to the wait before the next attempt.
        for attempt in 0..<delays.count {
            try Task.checkCancellation()
            do {
                var req = URLRequest(url: url)
                req.httpMethod = method
                
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

                return HTTPResponse(status: http.statusCode,
                                    headers: responseHeaders,
                                    data: data.isEmpty ? nil : data)
            } catch {
                if error is CancellationError || Task.isCancelled {
                    logger.debug("Request cancelled for host=\(url.host ?? "unknown", privacy: .public) path=\(url.path, privacy: .public)")
                    throw CancellationError()
                }

                if isTransient(error) {
                    logger.debug("Triggering retry. Retries: \(attempt, privacy: .public)")
                    // If this was the last attempt, bubble up the error.
                    if attempt >= delays.count - 1 { throw error }
                    
                    // Otherwise, wait the configured backoff before retrying.
                    let wait = delays[attempt + 1]
                    logger.debug("Sleeping for \(wait, privacy: .public) seconds")
                    try await Task.sleep(for: .seconds(Int(wait)))
                    logger.debug("Retrying query...")
                    continue
                } else {
                    logger.error("Non transient request error. Fatal: \(error, privacy: .public)")
                    throw error
                }
            }
        }
        
        // Defensive fallback; loop should either return or throw earlier.
        throw URLError(.cannotLoadFromNetwork)
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
