//
//  NwsClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/30/25.
//

import Foundation
import OSLog

protocol NwsClient: Sendable {
    func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data
    func fetchPointMetadata(for location: Coordinate2D) async throws -> Data
}

//https://api.weather.gov/alerts/active?point=39%2C-104
//https://api.weather.gov/alerts/active?status=actual&message_type=alert,update&point=39%2C-104

struct NwsHttpClient: NwsClient {
    private let http: HTTPClient
    private let logger = Logger.providersNwsClient
    private static let baseURL = URL(string: "https://api.weather.gov")!
    
    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }
    
    func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data {
        let (lat, lon) = truncatedCoordinates(for: location)
        logger.info("NWS request started endpoint=/alerts/active lat=\(lat, privacy: .private(mask: .hash)) lon=\(lon, privacy: .private(mask: .hash))")
        let point = "\(lat),\(lon)"
        let url = try makeNwsUrl(
            path: "/alerts/active",
            queryItems: [URLQueryItem(name: "point", value: point)]
        )
        
        return try await fetch(from: url)
    }
    
    func fetchPointMetadata(for location: Coordinate2D) async throws -> Data {
        let (lat, lon) = truncatedCoordinates(for: location)
        logger.info("NWS request started endpoint=/points lat=\(lat, privacy: .private(mask: .hash)) lon=\(lon, privacy: .private(mask: .hash))")
        let url = try makeNwsUrl(path: "/points/\(lat),\(lon)")
        
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

        let resp = try await http.get(url, headers: requestHeaders)
        try Task.checkCancellation()
        
        switch resp.classifyStatus() {
        case .success:
            break
        case .rateLimited(let retryAfter):
            let error = NwsError.rateLimited(retryAfterSeconds: retryAfter)
            logFailure(error: error, endpoint: url.path, status: resp.status)
            throw error
        case .serviceUnavailable(let retryAfter):
            let error = NwsError.serviceUnavailable(retryAfterSeconds: retryAfter)
            logFailure(error: error, endpoint: url.path, status: resp.status)
            throw error
        case .failure(let status):
            let error = NwsError.networkError(status: status)
            logFailure(error: error, endpoint: url.path, status: status)
            throw error
        }
        
        guard let data = resp.data else {
            logger.error("NWS response missing body endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public)")
            throw NwsError.missingData
        }
        
        return data
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
