//
//  HTTPDataDownloader.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog
import SwiftUI

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
    func clearCache()
}

// This is ok to leave as @unchecked sendable since we are only observing the metrics
// for now, and updating a refresh token that doesn't care about a particular source
// if any source is updatd, its ok to update the token. for now.
class CustomSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let logger = Logger.downloader
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let transactionMetrics = metrics.transactionMetrics.first else { return }

        switch transactionMetrics.resourceFetchType {
        case .localCache:
            logger.debug("Response for \(task.originalRequest?.url?.absoluteString ?? "request") was served from the local cache")
        case .networkLoad:
            logger.debug("Response for \(task.originalRequest?.url?.absoluteString ?? "request") was loaded from the network")
            let suite = UserDefaults(suiteName: "com.justinrooks.skyaware")
            guard let suite else { return }
            
            let lastGlobalSuccessAtKey = "lastGlobalSuccessAt"
            let now: Date = .now
            
            suite.set(now.timeIntervalSince1970, forKey: lastGlobalSuccessAtKey)
        default:
            logger.error("Response for \(task.originalRequest?.url?.absoluteString ?? "request") had an unknown fetch type")
        }
    }
}


public final class URLSessionHTTPClient: HTTPClient {
    private let logger = Logger.downloader
    private let session: URLSession
    private let delays: [UInt64] = [0, 5, 10, 15, 20] // seconds
    private let cache: URLCache
    
    public init(background: Bool = false) {
        let memoryCapacity = 4 * 1024 * 1024 // 4 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        self.cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "skyaware"
        )
        
        let config = {
            if background {
                let bConfig = URLSessionConfiguration.background(withIdentifier: "com.skyaware.background.url")
                bConfig.sessionSendsLaunchEvents = true
                
                return bConfig
            }
            else {
                let cfg = URLSessionConfiguration.default
                cfg.timeoutIntervalForRequest = 10 // Fail fast if request is slow
                cfg.timeoutIntervalForResource = 20
                
                return cfg
            }
        }()
        
        config.requestCachePolicy = .reloadRevalidatingCacheData
        config.urlCache = self.cache
        
        let myDelegate = CustomSessionDelegate()
        
        self.session = URLSession(configuration: config, delegate: myDelegate, delegateQueue: nil)
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

//    public func bgRequest(request: URLRequest) async throws -> Data? {
//        
//    }
    
    private func request(url: URL, method: String, headers: [String: String]) async throws -> HTTPResponse {
        // Try up to `delays.count` attempts. Delays array encodes backoff for retries,
        // where index+1 corresponds to the wait before the next attempt.
        for attempt in 0..<delays.count {
            if Task.isCancelled { throw CancellationError() }
            do {
                var req = URLRequest(url: url)
                req.httpMethod = method

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
