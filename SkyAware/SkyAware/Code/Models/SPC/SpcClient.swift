//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

/// Mapping enum that associates a product to its gis spc url
enum GeoJSONProduct: String, CustomStringConvertible {
    case categorical = "cat"       // this corresponds to the url builder, see buildUrl func below
    case tornado     = "torn"
    case hail        = "hail"
    case wind        = "wind"
    
    var description: String {
        switch self {
        case .categorical: return "categorical"
        case .tornado:     return "tornado"
        case .hail:        return "hail"
        case .wind:        return "wind"
        }
    }
}

/// Mapping enum that associates a product to its spc url
enum RssProduct: String, CustomStringConvertible {
    case convective  = "spcacrss"  // Convective outlooks only
    case meso        = "spcmdrss"  // Meso discussions only
    case watch       = "spcwwrss"  // Watches and status updates
    case combined    = "spcrss"    // All the watches, warnings, mesos, convective, & fire
    
    var description: String {
        switch self {
        case .convective: return "convective"
        case .meso:       return "meso"
        case .watch:      return "watch"
        case .combined:   return "combined"
        }
    }
}

protocol SpcClient: Sendable {
    /// Fetches an array of convective outlook RSS Items from SPC
    /// - Returns: array of RSS Items
    func fetchOutlookItems() async throws -> [Item]
    
    /// Fetches an array of meso RSS Items from SPC
    /// - Returns: array of RSS Items
    func fetchMesoItems() async throws -> [Item]
    
    /// Fetches an array of watch RSS Items from SPC
    /// - Returns: array of RSS Items
    func fetchWatchItems() async throws -> [Item]
    
    /// Fetches the categorical storm risk geojson
    func fetchStormRisk() async throws -> GeoJsonResult?
    func fetchHailRisk() async throws -> GeoJsonResult?
    func fetchWindRisk() async throws -> GeoJsonResult?
    func fetchTornadoRisk() async throws -> GeoJsonResult?
}

struct SpcHttpClient: SpcClient {
    private let http: HTTPClient
    private let parser: RSSFeedParser
    private let logger = Logger.spcClient
    
    init(http: HTTPClient = URLSessionHTTPClient(identifier: nil), parser: RSSFeedParser = RSSFeedParser()) {
        self.http = http
        self.parser = parser
    }
    
    /// Fetches an array of convective outlook RSS Items from SPC
    /// - Returns: array of RSS Items
    func fetchOutlookItems() async throws -> [Item] {
        try await fetchRssItems(for: .convective)
    }
    
    /// Fetches an array of meso RSS Items from SPC
    /// - Returns: array of RSS Items
    func fetchMesoItems() async throws -> [Item] {
        try await fetchRssItems(for: .meso)
    }
    
    /// Fetches an array of watch RSS Items from SPC
    /// - Returns: array of RSS Items
    func fetchWatchItems() async throws -> [Item] {
        try await fetchRssItems(for: .watch)
    }
    
    /// Fetches the categorical storm risk geojson
    func fetchStormRisk() async throws -> GeoJsonResult? {
        let (json, _) = try await getGeoJSONData(for: .categorical)
        return json
    }
    
    func fetchHailRisk() async throws -> GeoJsonResult? {
        let (json, _) = try await getGeoJSONData(for: .hail)
        return json
    }
    
    func fetchWindRisk() async throws -> GeoJsonResult? {
        let (json, _) = try await getGeoJSONData(for: .wind)
        return json
    }
    
    func fetchTornadoRisk() async throws -> GeoJsonResult? {
        let (json, _) = try await getGeoJSONData(for: .tornado)
        return json
    }
 
    /// Wrapper func that pulls the rss data from spc
    /// - Parameter product: product to obtain data for
    /// - Returns: an array of RSS Items
    private func fetchRssItems(for product: RssProduct) async throws -> [Item] {
        logger.info("Fetching data for \(String(describing: product))")
        let url = try getRssUrl(for: product)
        guard let data = try await fetchSpcData(for: url) else { return [] }
        
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        
        return rss.channel?.items ?? []
    }

    // MARK: GeoJson DTO Processing
    
    /// Tries to get GeoJSON data for the provided product
    /// - Parameter product: the product to query (cat, torn, hail, wind)
    /// - Returns: the GeoJSON result and bool indicating changed or not
    private func getGeoJSONData(for product: GeoJSONProduct) async throws -> (GeoJsonResult?, Bool) {
        logger.info("Fetching GeoJSON for \(String(describing: product))")
        let url = try getGeoJSONUrl(for: product)
        let data = try await fetchSpcData(for: url)
        
        guard let data else {
            return (GeoJsonResult(product: product, featureCollection: .empty), false)
        }
        
        let decoded = decodeGeoJSON(from: data)
        
        return (GeoJsonResult(product: product, featureCollection: decoded), true)
    }
    
    /// Decodes the provided Data into a GeoJSONFeatureCollection DTO
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    private func decodeGeoJSON(from data: Data) -> GeoJSONFeatureCollection {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(GeoJSONFeatureCollection.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            logger.error("GeoJSON decoding failed: Data corrupted – \(context.debugDescription)")
            return .empty
        } catch let DecodingError.keyNotFound(key, context) {
            logger.error("GeoJSON decoding failed: Missing key '\(key.stringValue)' – \(context.debugDescription)")
            return .empty
        } catch let DecodingError.typeMismatch(type, context) {
            logger.error("GeoJSON decoding failed: Type mismatch for type '\(type)' – \(context.debugDescription)")
            return .empty
        } catch let DecodingError.valueNotFound(value, context) {
            logger.error("GeoJSON decoding failed: Missing value '\(value)' – \(context.debugDescription)")
            return .empty
        } catch {
            logger.error("Unexpected GeoJSON decode error: \(error.localizedDescription)")
            return .empty
        }
    }
    
    // MARK: Private URL Building Helpers
    
    /// Fetches and decides "modified" by comparing returned validators (ETag / Last-Modified)
    /// against `prior`. The server always returns 200; no reliance on 304.
    /// Behavior:
    /// - If ETag present on both prior & new → modified iff ETag differs.
    /// - Else if Last-Modified present on both → modified iff Last-Modified differs.
    /// - Else (no comparable validators) → assume modified to be safe.
    private func fetchSpcData(for url: URL) async throws -> Data? {
        logger.info("Starting fetch (single GET) for \(url)")
  
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
    private func getGeoJSONUrl(for product: GeoJSONProduct) throws -> URL {
        try makeSPCURL(path: "products/outlook/day1otlk_\(product.rawValue).lyr.geojson")
    }
    
    /// Builds out the URL required to get SPC RSS products
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch rss data for the provided product
    private func getRssUrl(for product: RssProduct) throws -> URL {
        try makeSPCURL(path: "products/\(product.rawValue).xml")
    }
    
    /// Build an absolute SPC URL from a relative path, or throw on failure.
    private func makeSPCURL(path: String) throws -> URL {
        let base = "https://www.spc.noaa.gov/"
        guard let url = URL(string: base + path) else { throw SpcError.invalidUrl }
        return url
    }
}
