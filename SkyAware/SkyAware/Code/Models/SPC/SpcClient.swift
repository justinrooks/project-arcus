//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

enum GeoJSONProduct: String {
    case categorical = "cat"       // this corresponds to the url builder, see buildUrl func below
    case tornado     = "torn"
    case hail        = "hail"
    case wind        = "wind"
}

enum RssProduct: String {
    case convective  = "spcacrss"  // Convective outlooks only
    case meso        = "spcmdrss"  // Meso discussions only
    case combined    = "spcrss"    // All the watches, warnings, mesos, convective, & fire
}

final class SpcClient {
    private let http: HTTPClient
    private let logger = Logger.spcClient
    
    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }
    
    func fetchCombinedRssData() async throws -> Data? {
        let url = try getRssUrl(for: .combined)
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
        
        return data
    }
    
    /// Builds out the URL required to get geojson data from the SPC
    /// the url is mostly consistent between each product, so this
    /// standardizes that creation process
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch geojson data for the provided product
    func getGeoJSONUrl(for product: GeoJSONProduct) throws -> URL {
        try makeSPCURL(path: "products/outlook/day1otlk_\(product.rawValue).lyr.geojson")
    }
    
    /// Builds out the URL required to get SPC RSS products
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch rss data for the provided product
    func getRssUrl(for product: RssProduct) throws -> URL {
        try makeSPCURL(path: "products/\(product.rawValue).xml")
    }
    
    /// Build an absolute SPC URL from a relative path, or throw on failure.
    private func makeSPCURL(path: String) throws -> URL {
        let base = "https://www.spc.noaa.gov/"
        guard let url = URL(string: base + path) else { throw SpcError.invalidUrl }
        return url
    }
}
