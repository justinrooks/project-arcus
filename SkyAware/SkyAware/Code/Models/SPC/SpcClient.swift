//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import OSLog

enum GeoJSONProduct: String {
    case categorical = "cat" // this corresponds to the url builder, see buildUrl func below
    case tornado = "torn"
    case hail = "hail"
    case wind = "wind"
}

enum RssProduct: String {
    case convective = "spcacrss" // Convective outlooks only
    case meso = "spcmdrss"       // Meso discussions only
    case combined = "spcrss"           // All the watches, warnings, mesos, convective, & fire
}

// MARK: - Conditional fetch result helpers
struct ConditionalFetch {
    let value: Data?
    let newTag: HTTPCacheTag?
    let modified: Bool
}

private func conditionalHeaders(from prior: HTTPCacheTag?) -> [String: String] {
    var headers: [String: String] = [:]
    if let et = prior?.etag { headers["If-None-Match"] = et }
    if let lm = prior?.lastModified { headers["If-Modified-Since"] = lm }
    return headers
}

final class SpcClient {
    private let http: HTTPClient
    private let logger = Logger.spcClient
    
    init(http: HTTPClient = URLSessionHTTPClient(session: .fastFailing)) {
        self.http = http
    }
    
    func fetchGeoJson() async throws -> [GeoJsonResult] {
        logger.info("Fetching GeoJSON data from SPC")
        let client = self.http

        // 1) Precompute URLs synchronously (no concurrency, no self escaping).
        let catURL  = try getGeoJSONUrl(for: .categorical)
        let torURL  = try getGeoJSONUrl(for: .tornado)
        let hailURL = try getGeoJSONUrl(for: .hail)
        let windURL = try getGeoJSONUrl(for: .wind)

        // 2) Local helper that does not touch `self`.
        func download(_ url: URL) async throws -> Data {
            let resp = try await client.get(url, headers: [:])
            guard (200...299).contains(resp.status), let data = resp.data else {
                throw SpcError.missingGeoJsonData
            }
            return data
        }
        
        // 3) Fetch concurrently without capturing `self`.
        async let catData = download(catURL)
        async let torData  = download(torURL)
        async let hailData = download(hailURL)
        async let windData = download(windURL)
  
        let (catD, torD, hailD, windD) = try await (catData, torData, hailData, windData)
        
        // 4) Decode (non-throwing version recommended per earlier review).
        let categorical = decodeGeoJSON(from: catD)
        let tornado     = decodeGeoJSON(from: torD)
        let hail        = decodeGeoJSON(from: hailD)
        let wind        = decodeGeoJSON(from: windD)

        logger.info("GeoJSON data fetched successfully")
        return [
            GeoJsonResult(product: .categorical, featureCollection: categorical),
            GeoJsonResult(product: .tornado,     featureCollection: tornado),
            GeoJsonResult(product: .hail,        featureCollection: hail),
            GeoJsonResult(product: .wind,        featureCollection: wind)
        ]
    }
    
    /// Fetches and decides "modified" by comparing returned validators (ETag / Last-Modified)
    /// against `prior`. The server always returns 200; no reliance on 304.
    /// Behavior:
    /// - If ETag present on both prior & new → modified iff ETag differs.
    /// - Else if Last-Modified present on both → modified iff Last-Modified differs.
    /// - Else (no comparable validators) → assume modified to be safe.
    func fetchConditionalData(for url: URL, prior: HTTPCacheTag?) async throws -> ConditionalFetch {
        logger.info("Starting conditional fetch for \(url)")
        if let prior {
            do {
                let headResp = try await http.head(url, headers: conditionalHeaders(from: prior))
                let headTag = HTTPCacheTag(
                    etag: headResp.header("ETag"),
                    lastModified: headResp.header("Last-Modified")
                )
                
                // If the server returned validators and they match prior, short-circuit.
                if (!isCacheBusted(prior, headTag)) {
                    return ConditionalFetch(value: nil, newTag: headTag, modified: false)
                }
            } catch {
                // Network failure on HEAD → fall through to GET; GET will decide.
            }
        }

        // Either no prior, or validators differ, or HEAD didn’t return validators → GET full body.
        logger.info("Cache validators changed or unknown; performing GET")
        let resp = try await http.get(url, headers: [:])
        guard (200...299).contains(resp.status), let data = resp.data else {
            throw SpcError.missingData
        }
        
        let tag = HTTPCacheTag(
            etag: resp.header("ETag"),
            lastModified: resp.header("Last-Modified")
        )
        
        // If validators still match prior after GET, treat as not modified to save parsing.
        if (!isCacheBusted(prior, tag)) {
            return ConditionalFetch(value: nil, newTag: tag, modified: false)
        }
        
        logger.info("Fetched updated data")
        return ConditionalFetch(value: data, newTag: tag, modified: true)
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
    
    // MARK: Private Funcs
    /// Fetches the GeoJSON file at the url provided
    /// - Parameters:
    ///   - productUrl: the url of the product to fetch
    ///   - client: a http client to use for the connection
    /// - Returns: a data stream from the resource
    private func fetchGeoJsonFile(for productUrl: URL, with client: HTTPClient) async throws -> Data {
        let resp = try await client.get(productUrl, headers: [:])
        guard (200...299).contains(resp.status), let data = resp.data else {
            throw SpcError.missingGeoJsonData
        }
        
        return data
    }
    
    /// Build an absolute SPC URL from a relative path, or throw on failure.
    private func makeSPCURL(path: String) throws -> URL {
        let base = "https://www.spc.noaa.gov/"
        guard let url = URL(string: base + path) else { throw SpcError.invalidUrl }
        return url
    }
    
    /// Compares the prior cache tag to the current cache tag. When the etag or lastmodified date differ between
    /// the two, our cache is busted and we need to reload. If etag or lastmodified are equal between the two then
    /// no data changed, and we can adjust downstream.
    /// - Parameters:
    ///   - prior: cache tag from previous run, stored in SwiftData
    ///   - tag: new cache tag to compare against whats stored
    /// - Returns: true if cache is busted and we need to reload, false of prior and new cache tags are the same
    private func isCacheBusted(_ prior: HTTPCacheTag?, _ tag: HTTPCacheTag) -> Bool {
        guard let prior else { return true }
        
        if let et = tag.etag, let pet = prior.etag {
            return et != pet
        }
        if let lm = tag.lastModified, let plm = prior.lastModified {
            return lm != plm
        }
        
        logger.debug("No usable validators found; treating cache as outdated")
        // No usable validators -> safest to assume cache is busted
        return true
    }
    
    /// Decides the provided Data object into a GeoJSONFeatureCollection DTO object
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
}
