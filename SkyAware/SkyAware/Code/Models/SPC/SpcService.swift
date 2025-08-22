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
    private let now: () -> Date
    private let fetcher: SpcFetcher
    private let parser: RSSFeedParser
    private let logger = Logger.spcService

    init(client: SpcClient,
         now: @escaping () -> Date = { Date() },
         parser: RSSFeedParser = RSSFeedParser()) {
        self.client = client
        self.now = now
        self.parser = parser
        
        let sharedModelContainer: ModelContainer = {
            let schema = Schema([
                FeedCache.self
            ])
    //        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: []) // configurations: [modelConfiguration]
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
        
        self.fetcher = SpcFetcher(modelContainer: sharedModelContainer)
    }

    /// High-level "do a pass": RSS + Points. Keep it small; we can expand later.
    func refreshAll() async throws -> SpcServiceResult {
        var result = try await refreshRSS()
        let ptsRes = try await refreshPoints()
        
        result.geo = ptsRes.geo
        result.pointsChanged = ptsRes.changed
        
        return result
    }
        
    // MARK: - RSS (conditional)
    private func refreshRSS() async throws -> SpcServiceResult {
        logger.debug("Refreshing Spc RSS data")
        // 1) Pull prior data from SwiftData (if any)
        let cache = try await fetcher.get(FeedKey.outlookDay1RSS)
        let priorTag = httpCacheTag(from: cache)

        // 2) Conditional fetch
        let url = try client.getRssUrl(for: .combined)
//        let cf = try await client.fetchContitionalData(for: url, prior: priorTag)
        let cf = try await client.fetchConditionalData(for: url, prior: priorTag)

        // 3) If its modified and we have new data we'll continue
        //    but if modified is not true or value (data) is nil,
        //    then we'll fall into the else and return cached data.
        guard cf.modified, let data = cf.value else {
            if let cached = cache?.body {
                logger.debug("No change in eTag, returning cached data")
                let rss = try parseRSS(cached)
                return buildServiceResult(from: rss)
            }
            
            return SpcServiceResult(rssChanged: false)
        }

        // 4) Create a patch object to write updates to SwiftData
        //    Using a patch instead of the closure makes this
        //    operation thread safe.
        let patch = FeedCachePatch(
            etag: cf.newTag?.etag,
            lastModified: cf.newTag?.lastModified,
            lastSuccessAt: now(),
            nextPlannedAt: nil,
            body: data
        )
        try await fetcher.upsert(FeedKey.outlookDay1RSS, applying: patch)
        logger.debug("Cached data updated")
        
        // 5) Parse and return
        let rss = try parseRSS(data)
        
        logger.info("Rss parsed, returning data")
        return buildServiceResult(from: rss)
    }
    


    // MARK: - Points (Day 1) — keep v1 simple (unconditional)
    // If your endpoints support ETag, switch to client.fetchGeoJsonConditional(for:prior:)
    private func refreshPoints() async throws -> (geo: [GeoJsonResult], changed: Bool) {
        // If you want to do per-product conditional GETs, you can swap this call out:
        let geo = try await client.fetchGeoJson()

        // If you want to persist each product separately, loop and upsert per product.
        // For v1, keep a single row keyed to Day1 points and store the lastSuccessAt.

        
        
        
        
        
        
        
        //        try feeds.upsert(FeedKey.outlookDay1Points) { row in
//            row.lastSuccessAt = now()
            // row.etag / lastModified if you switch to conditional per product later
            // row.body = optionally store points Data if you want to reparse offline
//        }

        return (geo, true)
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
    
    /// Builds the SpcServiceResult object to return to the provider
    /// - Parameter rss: the rss to process
    /// - Returns: prepared SpcServiceResult object populated from the provided rss
    private func buildServiceResult(from rss: RSS) -> SpcServiceResult {
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
                                rssChanged: true)
    }
}
