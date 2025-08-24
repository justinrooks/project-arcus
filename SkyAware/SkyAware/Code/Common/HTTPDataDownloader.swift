//
//  HTTPDataDownloader.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

let validStatus = 200...299

public struct HTTPResponse {
    public let status: Int
    public let headers: [String: String]
    public let data: Data?
    
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

public protocol HTTPClient: Sendable {
    @available(*, deprecated, message: "No need for head calls right now, remove")
    func head(_ url: URL, headers: [String: String]) async throws -> HTTPResponse
    func get (_ url: URL, headers: [String: String]) async throws -> HTTPResponse
}

//extension URLSession {
//    static let fastFailing: URLSession = {
//        let config = URLSessionConfiguration.default
//        config.timeoutIntervalForRequest = 10 // Fail fast if request is slow
//        config.timeoutIntervalForResource = 20
//        
//        let memoryCapacity = 4 * 1024 * 1024 // 4 MB
//        let diskCapacity = 100 * 1024 * 1024 // 100 MB
//        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "skyaware")
//        
//        config.requestCachePolicy = .returnCacheDataElseLoad
//        config.urlCache = urlCache
//        return URLSession(configuration: config)
//    }()
//    
//    static let background: URLSession = {
//       let config = URLSessionConfiguration.background(withIdentifier: "com.skyaware.background.url")
//        config.sessionSendsLaunchEvents = true
//        return URLSession(configuration: config)
//    }()
//}


public final class URLSessionHTTPClient: HTTPClient {
    private let logger = Logger.downloader
    private let session: URLSession
    private let delays: [UInt64] = [0, 5, 10, 15, 20] // seconds
    private let cache: URLCache
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // Fail fast if request is slow
        config.timeoutIntervalForResource = 20
        
        let memoryCapacity = 4 * 1024 * 1024 // 4 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        self.cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "skyaware"
        )
        
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = self.cache
        
        self.session = URLSession(configuration: config)
    }
    
    public func head(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request(url: url, method: "HEAD", headers: headers)
    }
    
    public func get(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request(url: url, method: "GET", headers: headers)
    }

    public func getCachedResponse(for request: URLRequest) -> CachedURLResponse? {
        cache.cachedResponse(for: request)
    }
    
    public func clearCache() {
        cache.removeAllCachedResponses()
    }

    private func request(url: URL, method: String, headers: [String: String]) async throws -> HTTPResponse {
        // Try up to `delays.count` attempts. Delays array encodes backoff for retries,
        // where index+1 corresponds to the wait before the next attempt.
        for attempt in 0..<delays.count {
            if Task.isCancelled { throw CancellationError() }
            do {
                var req = URLRequest(url: url)
                req.httpMethod = method

                // Check the cache using the retained instance via the singleton
                if getCachedResponse(for: req) != nil {
                    logger.debug("Found cached response for \(url). Skipping network call.")
                } else {
                    logger.debug("No cached response found. Making network call.")
                }

                let (data, response) = try await session.data(for: req, delegate: nil)
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                return HTTPResponse(status: http.statusCode,
                                    headers: [:],
                                    data: data.isEmpty ? nil : data)
            } catch {
                if isTransient(error) {
                    logger.debug("Triggering retry. Retries: \(attempt)")
                    // If this was the last attempt, bubble up the error.
                    if attempt >= delays.count - 1 { throw error }
                    
                    // Otherwise, wait the configured backoff before retrying.
                    let wait = delays[attempt + 1]
                    logger.debug("Sleeping for \(wait) seconds")
                    try? await Task.sleep(for: .seconds(Int(wait)))
                    logger.debug("Retrying query...")
                    continue
                } else {
                    logger.error("Non transient request error. Fatal: \(error)")
                    throw error
                }
            }
        }
        
        // Defensive fallback; loop should either return or throw earlier.
        throw URLError(.cannotLoadFromNetwork)
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
