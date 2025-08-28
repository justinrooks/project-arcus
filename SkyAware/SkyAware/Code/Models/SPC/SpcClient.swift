//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

final class SpcClient {
    private let http: HTTPClient
    private let logger = Logger.spcClient
    private let builder = UrlBuilder()
    
    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }
    
    func fetchCombinedRssData() async throws -> Data? {
        let url = try builder.getRssUrl(for: .combined)
        return try await fetchSpcData(for: url)
    }
    
    /// Fetches and decides "modified" by comparing returned validators (ETag / Last-Modified)
    /// against `prior`. The server always returns 200; no reliance on 304.
    /// Behavior:
    /// - If ETag present on both prior & new → modified iff ETag differs.
    /// - Else if Last-Modified present on both → modified iff Last-Modified differs.
    /// - Else (no comparable validators) → assume modified to be safe.
    func fetchSpcData(for url: URL) async throws -> Data? {
        logger.info("Starting conditional fetch (single GET) for \(url)")
  
        let resp = try await http.get(url, headers: [:])
        
        logger.info("Response code: \(resp.status), for: \(url)")
        
        guard (200...299).contains(resp.status), let data = resp.data else {
            throw SpcError.networkError
        }
//        http.clearCache()
        return data
    }
}
