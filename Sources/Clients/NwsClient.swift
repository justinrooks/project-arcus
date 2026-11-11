//
//  NwsClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/30/25.
//

import Foundation
import OSLog

enum NwsZoneType: Sendable, Codable {
    case county
    case fire
}

protocol NwsClient: Sendable {
    func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data
    func fetchPointMetadata(for location: Coordinate2D) async throws -> Data
    func fetchZoneMetadata(for zoneType: NwsZoneType, and zone: String) async throws -> Data
}

//https://api.weather.gov/alerts/active?point=39%2C-104
//https://api.weather.gov/alerts/active?status=actual&message_type=alert,update&point=39%2C-104

//https://api.weather.gov/zones/fire/COZ245
//https://api.weather.gov/zones/county/COC001


struct NwsHttpClient: NwsClient {
    private let http: HTTPClient
    private let logger = Logger.providersNwsClient
    private static let baseURL = URL(string: "https://api.weather.gov")!
    private let fallbackPolicy: HTTPFallbackPolicy = .maximumAge(2 * 60)
    
    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }
    
    func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data {
        let (lat, lon) = truncatedCoordinates(for: location)
        let point = "\(lat),\(lon)"
        let url = try makeNwsUrl(
            path: "/alerts/active",
            queryItems: [
                URLQueryItem(name: "status", value: "actual"),
                URLQueryItem(name: "message_type", value: "alert,update"),
                URLQueryItem(name: "point", value: point)
            ]
        )
        logger.info(
            "NWS request started endpoint=\(endpointName(url), privacy: .public) mode=\(HTTPExecutionMode.current.logName, privacy: .public) request=active-alerts"
        )
        
        return try await fetch(from: url)
    }
    
    func fetchZoneMetadata(for zoneType: NwsZoneType, and zone: String) async throws -> Data {
        let url = switch zoneType {
            case .county: try makeNwsUrl(path: "/zones/county/\(zone)")
            case .fire: try makeNwsUrl(path: "/zones/fire/\(zone)")
        }
        logger.info(
            "NWS request started endpoint=\(endpointName(url), privacy: .public) mode=\(HTTPExecutionMode.current.logName, privacy: .public) request=zone-metadata"
        )
        
        return try await fetch(from: url)
    }
    
    func fetchPointMetadata(for location: Coordinate2D) async throws -> Data {
        let (lat, lon) = truncatedCoordinates(for: location)
        let url = try makeNwsUrl(path: "/points/\(lat),\(lon)")
        logger.info(
            "NWS request started endpoint=\(endpointName(url), privacy: .public) mode=\(HTTPExecutionMode.current.logName, privacy: .public) request=point-metadata"
        )
        
        return try await fetch(from: url)
    }
    
    private func truncatedCoordinates(for location: Coordinate2D) -> (Double, Double) {
        (
            location.latitude.truncated(to: 4), // NWS api only accepts 4 points of precision
            location.longitude.truncated(to: 4)
        )
    }

    private var requestHeaders: [String: String] {
        HTTPRequestHeaders.nws()
    }
    
    private func fetch(from url: URL) async throws -> Data {
        try Task.checkCancellation()

        let resp = try await http.get(url, headers: requestHeaders, fallbackPolicy: fallbackPolicy)
        try Task.checkCancellation()

        LocationEnrichmentDiagnostics.record("points_http_completed", token: LocationEnrichmentDiagnostics.pointTrace,
                                             networkSource: resp.source.description)
        if resp.source != .live {
            logger.notice("NWS response served from \(resp.source.description, privacy: .public) endpoint=\(endpointName(url), privacy: .public)")
        }

        switch resp.classifyStatus() {
        case .success:
            break
        case .notModified:
            // Downloader already rehydrates cached body for 304 when available.
            break
        case .rateLimited(let retryAfter):
            let error = NwsError.rateLimited(retryAfterSeconds: retryAfter)
            logFailure(error: error, endpoint: endpointName(url), status: resp.status)
            throw error
        case .serviceUnavailable(let retryAfter):
            let error = NwsError.serviceUnavailable(retryAfterSeconds: retryAfter)
            logFailure(error: error, endpoint: endpointName(url), status: resp.status)
            throw error
        case .failure(let status):
            let error = NwsError.networkError(status: status)
            logFailure(error: error, endpoint: endpointName(url), status: status)
            throw error
        }
        
        guard let data = resp.data else {
            logger.error("NWS response missing body endpoint=\(endpointName(url), privacy: .public) status=\(resp.status, privacy: .public)")
            throw NwsError.missingData
        }

        logger.info(
            "NWS request completed endpoint=\(endpointName(url), privacy: .public) status=\(resp.status, privacy: .public) source=\(resp.source.description, privacy: .public) bytes=\(data.count, privacy: .public)"
        )
        return data
    }

    private func endpointName(_ url: URL) -> String {
        if url.path.hasPrefix("/points/") { return "points" }
        if url.path.hasPrefix("/zones/") { return "zones" }
        return "alerts"
    }

    private func logFailure(error: NwsError, endpoint: String, status: Int) {
        switch error {
        case .rateLimited(let retryAfter):
            logger.warning("NWS rate limited endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
        case .serviceUnavailable(let retryAfter):
            logger.warning("NWS service unavailable endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
        default:
            logger.error("NWS request failed endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public)")
        }
    }
    
    /// Build an absolute NWS URL from a relative path, or throw on failure.
    private func makeNwsUrl(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw NwsError.invalidUrl
        }
        
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else { throw NwsError.invalidUrl }
        return url
    }
}
