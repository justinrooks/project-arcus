//
//  ArcusClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation
import OSLog

protocol ArcusClient: Sendable {
    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data
    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data
}

struct ArcusHttpClient: ArcusClient {
    private let http: HTTPClient
    private let baseURL: URL
    private let reachabilityReporter: any ArcusSignalReachabilityReporting
    private let logger = Logger.providersArcusClient
    // https://api.skyaware.app/api/v2/alerts?county=COC001&fire=COZ245&forecast=COZ045&h3=613167714648719359
    
    init(
        baseURL: URL = ArcusSignalConfiguration.defaultBaseURL,
        http: HTTPClient = URLSessionHTTPClient(),
        reachabilityReporter: any ArcusSignalReachabilityReporting = NoOpArcusSignalReachabilityReporter()
    ) {
        self.baseURL = baseURL
        self.http = http
        self.reachabilityReporter = reachabilityReporter
    }
    
    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        guard let cell else {
            logger.error("Missing required h3 cell address")
            throw ArcusError.missingH3Cell
        }
        let url = try makeUrl(
            path: ArcusSignalConfiguration.alertsPath,
            queryItems: [
                URLQueryItem(name: "county", value: county),
                URLQueryItem(name: "fire", value: fire),
                URLQueryItem(name: "forecast", value: forecast),
                URLQueryItem(name: "h3", value: "\(cell)")
            ]
        )
        logger.info(
            "Arcus request started endpoint=\(url.path, privacy: .public) mode=\(HTTPExecutionMode.current.logName, privacy: .public) queryScope=location-context"
        )
        
        return try await fetch(from: url)
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        var queryItems = [URLQueryItem(name: "id", value: id)]
        if let revisionSent {
            queryItems.append(
                URLQueryItem(
                    name: "sent",
                    value: revisionSent.ISO8601Format()
                )
            )
        }

        let url = try makeUrl(
            path: ArcusSignalConfiguration.alertsPath,
            queryItems: queryItems
        )
        logger.info(
            "Arcus request started endpoint=\(url.path, privacy: .public) mode=\(HTTPExecutionMode.current.logName, privacy: .public) queryScope=targeted-alert"
        )

        return try await fetch(from: url)
    }
    
    private var requestHeaders: [String: String] {
        HTTPRequestHeaders.arcus()
    }
    
    private func fetch(from url: URL) async throws -> Data {
        do {
            try Task.checkCancellation()

            let resp = try await http.get(url, headers: requestHeaders)
            try Task.checkCancellation()

            if resp.source != .live {
                logger.notice("Arcus response served from \(resp.source.description, privacy: .public) endpoint=\(url.path, privacy: .public)")
            }

            switch resp.classifyStatus() {
            case .success, .notModified:
                guard let data = resp.data else {
                    logger.error("Arcus response missing body endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public)")
                    throw ArcusError.missingData
                }

                switch resp.source {
                case .live, .cacheRevalidated304:
                    await reachabilityReporter.markReachable()
                case .cacheFallback:
                    await reachabilityReporter.markUnavailable()
                case .localCache:
                    // A local-cache hit does not prove Arcus is unreachable. Preserve prior signal state.
                    break
                }

                logger.info(
                    "Arcus request completed endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public) source=\(resp.source.description, privacy: .public) bytes=\(data.count, privacy: .public)"
                )
                return data
            case .rateLimited(let retryAfter):
                let error = ArcusError.rateLimited(retryAfterSeconds: retryAfter)
                logFailure(error: error, endpoint: url.path, status: resp.status)
                throw error
            case .serviceUnavailable(let retryAfter):
                let error = ArcusError.serviceUnavailable(retryAfterSeconds: retryAfter)
                logFailure(error: error, endpoint: url.path, status: resp.status)
                throw error
            case .failure(let status):
                let error = ArcusError.networkError(status: status)
                logFailure(error: error, endpoint: url.path, status: status)
                throw error
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await reachabilityReporter.markUnavailable()
            throw error
        }
    }
    
    private func logFailure(error: ArcusError, endpoint: String, status: Int) {
        switch error {
        case .rateLimited(let retryAfter):
            logger.warning("Arcus rate limited endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
        case .serviceUnavailable(let retryAfter):
            logger.warning("Arcus service unavailable endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
        default:
            logger.error("Arcus request failed endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public)")
        }
    }
    
    /// Build an absolute URL from a relative path, or throw on failure.
    private func makeUrl(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard let url = ArcusSignalConfiguration.url(from: baseURL, path: path, queryItems: queryItems) else {
            throw ArcusError.invalidUrl
        }
        return url
    }
}
