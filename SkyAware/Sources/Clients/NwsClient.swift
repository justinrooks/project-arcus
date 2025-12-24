//
//  NwsClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/30/25.
//

import Foundation
import OSLog

protocol NwsClient: Sendable {
    func fetchActiveAlertsJsonData(for location:Coordinate2D) async throws -> Data?
    func fetchPointMetadata(for location:Coordinate2D) async throws -> Data?
}

//https://api.weather.gov/alerts/active?point=39%2C-104
//https://api.weather.gov/alerts/active?status=actual&message_type=alert,update&point=39%2C-104

struct NwsHttpClient: NwsClient {
    private let http: HTTPClient
    private let logger = Logger.nwsClient
    
    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }
    
    func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data? {
        let lat = location.latitude.truncated(to: 4) // NWS api only accepts 4 points of precision
        let lon = location.longitude.truncated(to: 4)
        logger.info("Fetching active alerts for \(lat), \(lon)")
        let url = try makeNwsUrl(path: "alerts/active?point=\(lat),\(lon)")
        
        return try await fetch(from: url)
    }
    
    func fetchPointMetadata(for location: Coordinate2D) async throws -> Data? {
        let lat = location.latitude.truncated(to: 4) // NWS api only accepts 4 points of precision
        let lon = location.longitude.truncated(to: 4)
        logger.info("Fetching location metadata for \(lat), \(lon)")
        let url = try makeNwsUrl(path: "points/\(lat),\(lon)")
        
        return try await fetch(from: url)
    }
    
    private func fetch(from url: URL) async throws -> Data? {
        let headers = ["User-Agent": "SkyAware/0.1 (skyaware.app, contact: justinrooks@me.com)", "Accept": "application/geo+json"]
        let resp = try await http.get(url, headers: headers)
        
        guard (200...299).contains(resp.status), let data = resp.data else {
            logger.error("Error fetching NWS alert data: \(resp.status)")
            throw SpcError.networkError
        }

        return data
    }
    
    /// Build an absolute NWS URL from a relative path, or throw on failure.
    private func makeNwsUrl(path: String) throws -> URL {
        let base = "https://api.weather.gov/"
        guard let url = URL(string: base + path) else { throw NwsError.invalidUrl }
        return url
    }
}
