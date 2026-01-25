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
    func get (_ url: URL, headers: [String: String]) async throws -> HTTPResponse
    func clearCache()
}

public final class URLSessionHTTPClient: HTTPClient {
    private let logger = Logger.networkDownloader
    private let session: URLSession
    private let delays: [UInt64] = [0, 5, 10, 15] // seconds
    
    public init() {
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
    
    private func updateLastModified(date: Date) {
        
    }
    
    private func request(url: URL, method: String, headers: [String: String]) async throws -> HTTPResponse {
        // Try up to `delays.count` attempts. Delays array encodes backoff for retries,
        // where index+1 corresponds to the wait before the next attempt.
        for attempt in 0..<delays.count {
            //if Task.isCancelled { throw CancellationError() }
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
                
                if let mod = http.value(forHTTPHeaderField: "Last-Modified")?.fromRFC1123String(){
//                    logger.trace("LAST MOD: \(mod.toRFC1123String())")
                    
                    let suite = UserDefaults(suiteName: "com.justinrooks.skyaware")
                    if let suite {
                        let lastGlobalSuccessAtKey = "lastGlobalSuccessAt"
                        
                        suite.set(mod.timeIntervalSince1970, forKey: lastGlobalSuccessAtKey)
                    }
                }

                return HTTPResponse(status: http.statusCode,
                                    headers: [:],
                                    data: data.isEmpty ? nil : data)
            } catch {
                if isTransient(error) {
                    logger.debug("Triggering retry. Retries: \(attempt, privacy: .public)")
                    // If this was the last attempt, bubble up the error.
                    if attempt >= delays.count - 1 { throw error }
                    
                    // Otherwise, wait the configured backoff before retrying.
                    let wait = delays[attempt + 1]
                    logger.debug("Sleeping for \(wait, privacy: .public) seconds")
                    try? await Task.sleep(for: .seconds(Int(wait)))
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
