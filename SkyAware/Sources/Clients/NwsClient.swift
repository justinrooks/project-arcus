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
    func fetchActiveAlertsJsonData() async throws -> Data?
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
        logger.info("Fetching active alerts for \(location.latitude), \(location.longitude)")
        let url = try makeNwsUrl(path: "alerts/active?point=\(location.latitude),\(location.longitude)")
        
        return try await fetch(from: url)
    }
    
    func fetchActiveAlertsJsonData() async throws -> Data? {
        logger.info("Fetching all active alerts")
        let url = try makeNwsUrl(path: "/active?status=actual&message_type=alert,update")
        
        return try await fetch(from: url)
    }
    
    private func fetch(from url: URL) async throws -> Data?{
        let resp = try await http.get(url, headers: [:])
        
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
