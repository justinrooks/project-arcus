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
    private static let geoJSONAcceptHeader = "application/geo+json"
    
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
        [
            "User-Agent": Self.makeUserAgent(from: .main),
            "Accept": Self.geoJSONAcceptHeader
        ]
    }
    
    private func fetch(from url: URL) async throws -> Data {
        try Task.checkCancellation()

        let resp = try await http.get(url, headers: requestHeaders)
        try Task.checkCancellation()
        
        guard (200...299).contains(resp.status) else {
            let error = mappedError(for: resp)
            logFailure(error: error, endpoint: url.path, status: resp.status)
            throw error
        }
        
        guard let data = resp.data else {
            logger.error("NWS response missing body endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public)")
            throw NwsError.missingData
        }
        
        return data
    }

    private func mappedError(for response: HTTPResponse) -> NwsError {
        let retryAfter = retryAfterSeconds(from: response.header("Retry-After"))

        switch response.status {
        case 429:
            return .rateLimited(retryAfterSeconds: retryAfter)
        case 503:
            return .serviceUnavailable(retryAfterSeconds: retryAfter)
        default:
            return .networkError(status: response.status)
        }
    }

    private func retryAfterSeconds(from value: String?, now: Date = .now) -> Int? {
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

    private static func makeUserAgent(from bundle: Bundle) -> String {
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "SkyAware"
        let bundleID = bundle.bundleIdentifier ?? "skyaware.app"
        return "\(appName)/\(bundle.appVersion) (\(bundleID); build:\(bundle.buildNumber))"
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
