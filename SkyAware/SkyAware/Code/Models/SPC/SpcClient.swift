//
//  SpcClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

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
    
    init(http: HTTPClient = URLSessionHTTPClient(session: .fastFailing)) {
        self.http = http
    }
    
    func fetchGeoJson() async throws -> [GeoJsonResult] {
        do {
            let (categoricalData, tornadoData, hailData, windData) = try await (
                fetchGeoJsonFile(for: .categorical),
                fetchGeoJsonFile(for: .tornado),
                fetchGeoJsonFile(for: .hail),
                fetchGeoJsonFile(for: .wind))
            
            let (categorical, tornado, hail, wind) = try await (
                decodeGeoJSON(from: categoricalData),
                decodeGeoJSON(from: tornadoData),
                decodeGeoJSON(from: hailData),
                decodeGeoJSON(from: windData))
            
            return [
                GeoJsonResult(product: .categorical, featureCollection: categorical),
                GeoJsonResult(product: .tornado, featureCollection: tornado),
                GeoJsonResult(product: .hail, featureCollection: hail),
                GeoJsonResult(product: .wind, featureCollection: wind)
            ]
            
        } catch {
            print(error.localizedDescription)
            throw SpcError.missingGeoJsonData
        }
    }
    
    /// Conditional fetch for a single product...
    func fetchContitionalData(for url: URL, prior: HTTPCacheTag?) async throws -> ConditionalFetch {
        if let prior {
            do {
                let headResp = try await http.head(url, headers: [:])
                let headTag = HTTPCacheTag(
                    etag: headResp.header("ETag"),
                    lastModified: headResp.header("Last-Modified")
                )
                // If the server returned validators and they match prior, short-circuit.
                if (!isCacheBusted(prior, headTag)) {
                    return ConditionalFetch(value: nil, newTag: headTag, modified: false)
                }
                // If HEAD didn’t return validators, fall through to GET.
            } catch {
                // Network failure on HEAD → fall through to GET; GET will decide.
            }
        }

        let resp = try await http.get(url, headers: [:])
        guard (200...299).contains(resp.status), let data = resp.data else {
            throw SpcError.missingData
        }
        
        // Build up a HTTPCacheTag to record the etag and last modified values
        let tag = HTTPCacheTag(
            etag: resp.header("ETag"),
            lastModified: resp.header("Last-Modified")
        )
        
        // If validators still match prior after GET, treat as not modified to save parsing.
        if (!isCacheBusted(prior, tag)) {
            return ConditionalFetch(value: nil, newTag: tag, modified: false)
        }
        
        return ConditionalFetch(value: data, newTag: tag, modified: true)
    }
    
    /// Conditional GeoJSON fetch for a single product. Returns notModified=true on 304.
//    func fetchGeoJsonConditional(for product: Product, prior: HTTPCacheTag?) async throws -> ConditionalFetch {
//        let url = try buildGeoJsonUrl(for: product)
//        if let prior {
//            do {
//                let headResp = try await http.head(url, headers: [:])
//                let headTag = HTTPCacheTag(
//                    etag: headResp.header("ETag"),
//                    lastModified: headResp.header("Last-Modified")
//                )
//                // If the server returned validators and they match prior, short-circuit.
//                if (!isCacheBusted(prior, headTag)) {
//                    return ConditionalFetch(value: nil, newTag: headTag, modified: false)
//                }
//                // If HEAD didn’t return validators, fall through to GET.
//            } catch {
//                // Network failure on HEAD → fall through to GET; GET will decide.
//            }
//        }
//
//        let resp = try await http.get(url, headers: [:])
//        guard (200...299).contains(resp.status), let data = resp.data else {
//            throw SpcError.missingGeoJsonData
//        }
//        
//        // Build up a HTTPCacheTag to record the etag and last modified values
//        let tag = HTTPCacheTag(
//            etag: resp.header("ETag"),
//            lastModified: resp.header("Last-Modified")
//        )
//        
//        // If validators still match prior after GET, treat as not modified to save parsing.
//        if (!isCacheBusted(prior, tag)) {
//            return ConditionalFetch(value: nil, newTag: tag, modified: false)
//        }
//        
//        return ConditionalFetch(value: data, newTag: tag, modified: true)
//        
////        let resp = try await http.get(url, headers: conditionalHeaders(from: prior))
////        if resp.status == 304 { return ConditionalFetch(value: nil, newTag: nil, modified: false) }
////        guard (200...299).contains(resp.status), let data = resp.data else {
////            throw SpcError.missingGeoJsonData
////        }
////        let tag = HTTPCacheTag(etag: resp.header("ETag"), lastModified: resp.header("Last-Modified"))
////        return ConditionalFetch(value: data, newTag: tag, modified: true)
//    }
    
    /// Conditional RSS fetch using ETag/Last-Modified without relying on HTTP 304.
    /// Strategy: if prior validators exist, issue a HEAD probe; if validators match, skip GET.
    /// Otherwise, GET the feed; if validators still match prior, treat as not modified.
//    func fetchRss(prior: HTTPCacheTag?) async throws -> ConditionalFetch {
//        let feedURL = try buildRssUrl(for: .combined)
//        // If we have prior validators, try a cheap HEAD call first.
//        if let prior {
//            do {
//                let headResp = try await http.head(feedURL, headers: [:])
//                let headTag = HTTPCacheTag(
//                    etag: headResp.header("ETag"),
//                    lastModified: headResp.header("Last-Modified")
//                )
//                // If the server returned validators and they match prior, short-circuit.
//                if (!isCacheBusted(prior, headTag)) {
//                    return ConditionalFetch(value: nil, newTag: headTag, modified: false)
//                }
//                // If HEAD didn’t return validators, fall through to GET.
//            } catch {
//                // Network failure on HEAD → fall through to GET; GET will decide.
//            }
//        }
//        
//        // If we made it here, then we probably need to fetch new data
//        // Perform GET and decide based on validators.
//        let resp = try await http.get(feedURL, headers: [:])
//        guard (200...299).contains(resp.status), let data = resp.data else {
//            throw SpcError.missingRssData
//        }
//        
//        // Build up a HTTPCacheTag to record the etag and last modified values
//        let tag = HTTPCacheTag(
//            etag: resp.header("ETag"),
//            lastModified: resp.header("Last-Modified")
//        )
//        
//        // If validators still match prior after GET, treat as not modified to save parsing.
//        if (!isCacheBusted(prior, tag)) {
//            return ConditionalFetch(value: nil, newTag: tag, modified: false)
//        }
//        
//        return ConditionalFetch(value: data, newTag: tag, modified: true)
//    }
    
    private func fetchGeoJsonFile(for product: GeoJSONProduct) async throws -> Data {
        let productUrl = try getGeoJSONUrl(for: product)
        let resp = try await http.get(productUrl, headers: [:])
        guard (200...299).contains(resp.status), let data = resp.data else {
            throw SpcError.missingGeoJsonData
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
    
    /// Builds out the URL required to get SPC Rss products from the SPC
    /// - Parameter product: the prodcut to fetch
    /// - Returns: a url to use to fetch rss data for the provided product
    func getRssUrl(for product: RssProduct) throws -> URL {
        try makeSPCURL(path: "products/\(product.rawValue).xml")
    }
    
    /// Build an absolute SPC URL from a relative path, or throw on failure.
    @inline(__always)
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
        if let prior {
            if let et = tag.etag, let pet = prior.etag, et == pet {
                return false
            }
            if let lm = tag.lastModified, let plm = prior.lastModified, lm == plm {
                return false
            }
        }
        
        return true
    }
    
    /// Decides the provided Data object into a GeoJSONFeatureCollection DTO object
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    private func decodeGeoJSON(from data: Data) async throws -> GeoJSONFeatureCollection {
        let decoder = JSONDecoder()
        
        do {
            let decoded = try decoder.decode(GeoJSONFeatureCollection.self, from: data)
            return decoded
        } catch let DecodingError.dataCorrupted(context) {
            print("GeoJSON decoding failed: Data corrupted –", context.debugDescription)
            return .empty
        } catch let DecodingError.keyNotFound(key, context) {
            print("GeoJSON decoding failed: Missing key '\(key.stringValue)' –", context.debugDescription)
            return .empty
        } catch let DecodingError.typeMismatch(type, context) {
            print("GeoJSON decoding failed: Type mismatch for type '\(type)' –", context.debugDescription)
            return .empty
        } catch let DecodingError.valueNotFound(value, context) {
            print("GeoJSON decoding failed: Missing value '\(value)' –", context.debugDescription)
            return .empty
        } catch {
            print("Unexpected GeoJSON decode error:", error.localizedDescription)
            return .empty
        }
    }
}
