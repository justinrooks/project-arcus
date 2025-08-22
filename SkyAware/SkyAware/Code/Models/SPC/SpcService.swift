//
//  SpcService.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/14/25.
//

import Foundation
import SwiftData
import OSLog

struct SpcServiceResult {
    var outlooks: [ConvectiveOutlook] = []
    var mesos:    [MesoscaleDiscussion] = []
    var watches:  [Watch] = []
    var geo:      [GeoJsonResult] = []
    var rssChanged: Bool = false
    var pointsChanged: Bool = false
}

/// Talks to SpcClient (network) and FeedCacheRepository (SwiftData)
/// 1. Fetch the data from SPC
/// 2. Save that data to SwiftData if different etag
/// 3. return saved data to Provider
final class SpcService {
    private let client: SpcClient
    private let now: @Sendable () -> Date
    private let fetcher: SpcFetcher
    private let parser: RSSFeedParser
    private let logger = Logger.spcService
    
    // Preferred for tests / app composition:
    init(client: SpcClient,
         fetcher: SpcFetcher,
         now: @escaping @Sendable () -> Date = { Date() },
         parser: RSSFeedParser = RSSFeedParser()) {
        self.client = client
        self.now = now
        self.parser = parser
        self.fetcher = fetcher
    }
    
    /// Convenience initializer that builds a default container
    /// - Parameters:
    ///   - client: SpcClient instance
    ///   - now: Optional specific date
    ///   - parser: Optional RssParser
    convenience init(client: SpcClient,
                     now: @Sendable @escaping () -> Date = { Date() },
                     parser: RSSFeedParser = RSSFeedParser()) {
        
        let sharedModelContainer: ModelContainer = {
            let schema = Schema([FeedCache.self])
            //        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
            do { return try ModelContainer(for: schema, configurations: []) }// configurations: [modelConfiguration]
            catch { fatalError("Could not create ModelContainer: \(error)") }
        }()
        
        self.init(client: client,
                  fetcher: SpcFetcher(modelContainer: sharedModelContainer),
                  now: now,
                  parser: parser)
    }
    
    /// High-level "do a pass": RSS + Points. Keep it small; we can expand later.
    func refreshAll() async throws -> SpcServiceResult {
        logger.info("Refreshing SPC RSS & Points data")
        var result = try await refreshRSS()
        let ptsRes = try await refreshPoints()
        
        result.geo = ptsRes.geo
        result.pointsChanged = ptsRes.changed
        
        return result
    }
    
    // MARK: Private Helper Funcs
    
    /// Fetches the convective RSS data
    /// - Returns: SpcServiceResult object containing the parsed rss data as objects
    private func refreshRSS() async throws -> SpcServiceResult {
        logger.debug("Refreshing Spc RSS data")
        // 1) Pull prior data from SwiftData (if any)
        let cache = try await fetcher.get(FeedKey.outlookDay1RSS)
        let priorTag = httpCacheTag(from: cache)
        
        // 2) Conditional fetch
        let url = try client.getRssUrl(for: .combined)
        let cf = try await client.fetchConditionalData(for: url, prior: priorTag)
        
        // 3) If its modified and we have new data we'll continue
        //    but if modified is not true or value (data) is nil,
        //    then we'll fall into the else and return cached data.
        guard cf.modified, let data = cf.value else {
            if let cached = cache?.body {
                logger.debug("Validators unchanged, returning cached data")
                let rss = try parseRSS(cached)
                return buildServiceResult(from: rss, changed: false)
            }
            
            return SpcServiceResult(rssChanged: false)
        }
        
        try await updateCacheData(for: cf, with: data, key: FeedKey.outlookDay1RSS)
        
        // 5) Parse and return
        let rss = try parseRSS(data)
        
        logger.info("Rss parsed, returning data")
        return buildServiceResult(from: rss)
    }
    
    /// Fetches the points data for severe weather
    /// - Returns: array of GeoJsonResult and a bool indicating if any of the products changed
    private func refreshPoints() async throws -> (geo: [GeoJsonResult], changed: Bool) {
        logger.debug("Refreshing SPC Points data")
        
        //        // Precompute inputs synchronously (no concurrency, no self escaping).
        //        let inputs: [(product: GeoJSONProduct, key: String, prior: HTTPCacheTag?, url: URL)] = try {
        //            let prods: [GeoJSONProduct] = [.categorical, .tornado, .hail, .wind]
        //            return try prods.map { p in
        //                let key = getKey(for: p)
        //                let cache = try await fetcher.get(key)  // still awaited here; if desired, hoist to group too
        //                return (p, key, httpCacheTag(from: cache), try client.getGeoJSONUrl(for: p))
        //            }
        //        }()
        //        
        //        // Capture only the needed Sendable deps.
        //        let fetcher = self.fetcher
        //        let client  = self.client
        //        let now     = self.now
        //        
        //        struct Item { let result: GeoJsonResult?; let changed: Bool }
        //        
        //        func fetchOne(_ input: (product: GeoJSONProduct, key: String, prior: HTTPCacheTag?, url: URL)) async throws -> Item {
        //            let cf = try await client.fetchConditionalData(for: input.url, prior: input.prior)
        //            guard cf.modified, let data = cf.value else {
        //                if let cached = try await fetcher.get(input.key)?.body {
        //                    let cachedGeo = decodeGeoJSON(from: cached)
        //                    return Item(result: GeoJsonResult(product: input.product, featureCollection: cachedGeo), changed: false)
        //                }
        //                // Intentional: first run with "unchanged" validators → treat as no data.
        //                return Item(result: GeoJsonResult(product: input.product, featureCollection: .empty), changed: false)
        //            }
        //            // Update cache and decode
        //            let patch = FeedCachePatch(etag: cf.newTag?.etag, lastModified: cf.newTag?.lastModified, lastSuccessAt: now(), nextPlannedAt: nil, body: data)
        //            try await fetcher.upsert(input.key, applying: patch)
        //            let decoded = decodeGeoJSON(from: data)
        //            return Item(result: GeoJsonResult(product: input.product, featureCollection: decoded), changed: true)
        //        }
        //        
        //        // Run in parallel without capturing self inside the tasks.
        //        async let a = fetchOne(inputs[0])
        //        async let b = fetchOne(inputs[1])
        //        async let c = fetchOne(inputs[2])
        //        async let d = fetchOne(inputs[3])
        //        let (ra, rb, rc, rd) = try await (a, b, c, d)
        //        
        //        let all = [ra, rb, rc, rd]
        //        let changed = all.contains { $0.changed }
        //        let geo = all.compactMap { $0.result }
        //        return (geo, changed)
        
        let (cat, cCh)  = try await getGeoJSONData(for: .categorical)
        let (torn, tCh) = try await getGeoJSONData(for: .tornado)
        let (hail, hCh) = try await getGeoJSONData(for: .hail)
        let (wind, wCh) = try await getGeoJSONData(for: .wind)
        
        let changed = cCh || tCh || hCh || wCh
        return ([cat, torn, hail, wind].compactMap{ $0 }, changed)
    }
    
    /// Convenience function for mapping a product to a FeedKey for SwiftData
    /// - Parameter product: product to map
    /// - Returns: string value of the key
    private func getKey(for product: GeoJSONProduct) -> String {
        switch product {
        case .categorical: return FeedKey.categoricalGeoJSON
        case .tornado:     return FeedKey.tornadoGeoJSON
        case .hail:        return FeedKey.hailGeoJSON
        case .wind:        return FeedKey.windGeoJSON
        }
    }
    
    /// Tries to get GeoJSON data for the provided product
    /// - Parameter product: the product to query (cat, torn, hail, wind)
    /// - Returns: the GeoJSON result and bool indicating changed or not
    private func getGeoJSONData(for product: GeoJSONProduct) async throws -> (GeoJsonResult?, Bool) {
        logger.debug("Getting GeoJSON for \(product.rawValue)")
        // Get data, either from cache or server
        let key = getKey(for: product)
        let cache = try await fetcher.get(key)
        let priorTag = httpCacheTag(from: cache)
        
        let url = try client.getGeoJSONUrl(for: product)
        let cf = try await client.fetchConditionalData(for: url, prior: priorTag)
        
        // 3) If its modified and we have new data we'll continue
        //    but if modified is not true or value (data) is nil,
        //    then we'll fall into the else and return cached data.
        guard cf.modified, let data = cf.value else {
            if let cached = cache?.body {
                logger.debug("Validators unchanged, returning cached GeoJSON")
                // Convert to Objects
                let cachedGeo = decodeGeoJSON(from: cached)
                return (GeoJsonResult(product: product, featureCollection: cachedGeo), false)
            }
            
            return (GeoJsonResult(product: product, featureCollection: .empty), false)
        }
        
        // Refresh the cached data
        try await updateCacheData(for: cf, with: data, key: key)
        
        // Convert to Objects
        let decoded = decodeGeoJSON(from: data)
        
        return (GeoJsonResult(product: product, featureCollection: decoded), true)
    }
    
    /// Tries to update the cached data in SwiftData with the provided data for the provided key
    /// - Parameters:
    ///   - fetch: header info including the etag and last modified
    ///   - data: a data stream to persist in the body
    ///   - key: FeedKey identifier in SwiftData
    private func updateCacheData(for fetch: ConditionalFetch, with data: Data?, key: String) async throws {
        // 4) Create a patch object to write updates to SwiftData
        //    Using a patch instead of the closure makes this
        //    operation thread safe.
        let patch = FeedCachePatch(
            etag: fetch.newTag?.etag,
            lastModified: fetch.newTag?.lastModified,
            lastSuccessAt: now(),
            nextPlannedAt: nil,
            body: data
        )
        
        try await fetcher.upsert(key, applying: patch)
        logger.debug("Cached data updated")
    }
    
    /// Builds an HTTP cache tag (ETag/Last-Modified) from a stored cache row.
    private func httpCacheTag(from cache: FeedCache?) -> HTTPCacheTag? {
        guard let cache else { return nil }
        return HTTPCacheTag(etag: cache.etag, lastModified: cache.lastModified)
    }
    
    /// Parse RSS data or throw a standard parsing error.
    private func parseRSS(_ data: Data) throws -> RSS {
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        return rss
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
    
    /// Builds the SpcServiceResult object to return to the provider
    /// - Parameter RSS: the RSS to process
    /// - Returns: prepared SpcServiceResult object populated from the provided RSS
    private func buildServiceResult(from rss: RSS, changed: Bool = true) -> SpcServiceResult {
        let items = rss.channel?.items ?? []
        let outlooks = items
            .filter { ($0.title ?? "").contains(" Convective Outlook") }
            .compactMap { ConvectiveOutlook.from(rssItem: $0) }
        
        let mesos = items
            .filter { ($0.title ?? "").contains("SPC MD ") }
            .compactMap { MesoscaleDiscussion.from(rssItem: $0) }
        
        let watches = items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
            .compactMap { Watch.from(rssItem: $0) }
        
        return SpcServiceResult(outlooks: outlooks,
                                mesos: mesos,
                                watches: watches,
                                rssChanged: changed)
    }
}
