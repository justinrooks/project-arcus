//
//  HTTPDataDownloader.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

let validStatus = 200...299

public struct HTTPResponse {
    public let status: Int
    public let headers: [String: String]
    public let data: Data?
    
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

public protocol HTTPClient {
    func head(_ url: URL, headers: [String: String]) async throws -> HTTPResponse
    func get (_ url: URL, headers: [String: String]) async throws -> HTTPResponse
}

extension URLSession {
    static let fastFailing: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // Fail fast if request is slow
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()
    
    static let background: URLSession = {
       let config = URLSessionConfiguration.background(withIdentifier: "com.skyaware.background.url")
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config)
    }()
}


public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let delays: [UInt64] = [0, 5, 10, 15, 20] // seconds
    public init(session: URLSession) {
        self.session = session
    }
    
    public func head(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request(url: url, method: "HEAD", headers: headers)
    }
    
    public func get(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        try await request(url: url, method: "GET", headers: headers)
    }
    
    private func request(url: URL, method: String, headers: [String: String]) async throws -> HTTPResponse {
        // Try up to `delays.count` attempts. Delays array encodes backoff for retries,
        // where index+1 corresponds to the wait before the next attempt.
        for attempt in 0..<delays.count {
            if Task.isCancelled { throw CancellationError() }
            do {
                var req = URLRequest(url: url)
                req.httpMethod = method
                headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
                
                let (data, response) = try await session.data(for: req, delegate: nil)
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let headerMap: [String: String] = http.allHeaderFields.reduce(into: [:]) {
                    dict, kv in
                    if let k = kv.key as? String {
                        dict[k] = String(describing: kv.value)
                    }
                }
                
                return HTTPResponse(status: http.statusCode,
                                    headers: headerMap,
                                    data: data.isEmpty ? nil : data)
            } catch {
                if isTransient(error) {
                    print("Triggering retry. Retries: \(attempt)")
                    // If this was the last attempt, bubble up the error.
                    if attempt >= delays.count - 1 { throw error }
                    
                    // Otherwise, wait the configured backoff before retrying.
                    let wait = delays[attempt + 1]
                    print("Sleeping for \(wait) seconds")
                    try? await Task.sleep(for: .seconds(Int(wait)))
                    print("Retrying query...")
                    continue
                } else {
                    print("Non transient request error. Fatal: \(error)")
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
