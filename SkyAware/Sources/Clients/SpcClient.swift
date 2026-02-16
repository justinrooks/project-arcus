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

/// Mapping enum that associates a product to its spc xml url
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
    /// Fetches  the backing data for rss product
    ///  includes Convective outlook, Meso Discussions, Severe Watches
    func fetchRssData(for product: RssProduct) async throws -> Data
    
    /// Fetches the backing data for geojson
    /// includes Categorical, Hail, Wind, Tornado geojson polygons
    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data
}

struct SpcHttpClient: SpcClient {
    private let http: HTTPClient
    private let logger = Logger.providersSpcClient
    private static let baseURL = URL(string: "https://www.spc.noaa.gov")!
    
    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }
    
    /// Tries to get GeoJSON data for the provided product
    /// - Parameter product: the product to query (cat, torn, hail, wind)
    /// - Returns: the Data
    func fetchGeoJsonData(for product: GeoJSONProduct) async throws -> Data {
        logger.info("Fetching GeoJSON for \(String(describing: product), privacy: .public)")
        let url = try getGeoJSONUrl(for: product)
        return try await fetchSpcData(for: url, headers: HTTPRequestHeaders.spcGeoJSON())
    }
    
    /// Wrapper func that pulls the rss data from spc
    /// - Parameter product: product to obtain data for
    /// - Returns: the Data
    func fetchRssData(for product: RssProduct) async throws -> Data {
        logger.info("Fetching data for \(String(describing: product), privacy: .public)")
        let url = try getRssUrl(for: product)
        return try await fetchSpcData(for: url, headers: HTTPRequestHeaders.spcRss())
    }
    
    /// Fetches  data using the http session
    private func fetchSpcData(for url: URL, headers: [String: String]) async throws -> Data {
        try Task.checkCancellation()

        let resp = try await http.get(url, headers: headers)
        try Task.checkCancellation()

        switch resp.classifyStatus() {
        case .success:
            break
        case .rateLimited(let retryAfter):
            logger.warning("SPC rate limited endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
            throw SpcError.rateLimited(retryAfterSeconds: retryAfter)
        case .serviceUnavailable(let retryAfter):
            logger.warning("SPC service unavailable endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
            throw SpcError.serviceUnavailable(retryAfterSeconds: retryAfter)
        case .failure(let status):
            logger.error("SPC request failed endpoint=\(url.path, privacy: .public) status=\(status, privacy: .public)")
            throw SpcError.networkError(status: status)
        }

        guard let data = resp.data else {
            logger.error("SPC response missing body endpoint=\(url.path, privacy: .public) status=\(resp.status, privacy: .public)")
            throw SpcError.missingData
        }

        return data
    }

    // MARK: Private URL Building Helpers
    
    /// Builds out the URL required to get geojson data from the SPC
    /// the url is mostly consistent between each product, so this
    /// standardizes that creation process
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch geojson data for the provided product
    private func getGeoJSONUrl(for product: GeoJSONProduct) throws -> URL {
        try makeSPCURL(path: "/products/outlook/day1otlk_\(product.rawValue).lyr.geojson")
    }
    
    /// Build an absolute URL for a SPC RSS products
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch rss data for the provided product
    private func getRssUrl(for product: RssProduct) throws -> URL {
        try makeSPCURL(path: "/products/\(product.rawValue).xml")
    }
    
    /// Build an absolute SPC URL from a relative path, or throw on failure.
    private func makeSPCURL(path: String) throws -> URL {
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw SpcError.invalidUrl
        }
        components.path = path
        guard let url = components.url else { throw SpcError.invalidUrl }
        return url
    }
}
