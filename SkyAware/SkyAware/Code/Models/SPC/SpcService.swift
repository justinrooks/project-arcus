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
    private let builder = UrlBuilder()
    
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
        let data = try await client.fetchCombinedRssData()
        
        guard let data else {
            return SpcServiceResult(rssChanged: false)
        }

        let rss = try parseRSS(data)
        
        logger.info("Rss parsed, returning data")
        return buildServiceResult(from: rss)
    }
    
    /// Fetches the points data for severe weather
    /// - Returns: array of GeoJsonResult and a bool indicating if any of the products changed
    private func refreshPoints() async throws -> (geo: [GeoJsonResult], changed: Bool) {
        logger.debug("Refreshing SPC Points data")
        
        let (cat, cCh)  = try await getGeoJSONData(for: .categorical)
        let (torn, tCh) = try await getGeoJSONData(for: .tornado)
        let (hail, hCh) = try await getGeoJSONData(for: .hail)
        let (wind, wCh) = try await getGeoJSONData(for: .wind)
        
        let changed = cCh || tCh || hCh || wCh
        return ([cat, torn, hail, wind].compactMap{ $0 }, changed)
    }

    /// Tries to get GeoJSON data for the provided product
    /// - Parameter product: the product to query (cat, torn, hail, wind)
    /// - Returns: the GeoJSON result and bool indicating changed or not
    private func getGeoJSONData(for product: GeoJSONProduct) async throws -> (GeoJsonResult?, Bool) {
        logger.debug("Getting GeoJSON for \(product.rawValue)")
        let url = try builder.getGeoJSONUrl(for: product)
        let data = try await client.fetchSpcData(for: url)
        
        guard let data else {
            return (GeoJsonResult(product: product, featureCollection: .empty), false)
        }
        
        let decoded = decodeGeoJSON(from: data)
        
        return (GeoJsonResult(product: product, featureCollection: decoded), true)
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
