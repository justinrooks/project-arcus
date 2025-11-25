//
//  WatchRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor WatchRepo {
    private let logger = Logger.watchRepo
    private let parser: RSSFeedParser = RSSFeedParser()
    
    func refreshWatches(using client: any SpcClient) async throws {
        let data = try await client.fetchRssData(for: .watch)

        guard let data else {
            logger.warning("No severe watches found")
            return
        }
                
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        
        guard let channel = rss.channel else {
            logger.warning("Error parsing severe watch channel items")
            return
        }
        
        // Filters out some odd contents
        let watches = channel.items
            .filter {
                guard let t = $0.title else { return false }
                return t.contains("Watch") && !t.contains("Status Reports")
            }
            .compactMap { makeWatchModel(from: $0) }
        
        try upsert(watches)
        logger.debug("Parsed \(watches.count) watch\(watches.count > 1 ? "es" : "") from SPC")
    }
    
    /// Removes any expired mesoscale discussions from datastore
    /// - Parameter now: defaults to now
    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired watches")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<WatchModel> { $0.validEnd < now }
        var desc = FetchDescriptor<WatchModel>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count) to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Expired watches purged")
    }
    
    private func makeWatchModel(from rssItem: Item) -> WatchModel? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let issued = pubDateString.fromRFC822()
        else { return nil }
        
        let wwNumber = WatchParser.parseWatchNumber(from: link) ?? {
            // Fallback: try to read from title if present
            if let r = title.range(of: #"\b(\d{3,4})\b"#, options: .regularExpression) { return Int(title[r]) } else { return nil }
        }() ?? -1
        
        // Valid range (UTC), fallback to issued+2h if missing
        let validPair = WatchParser.parseValid(summary, issued: issued)
        let validStart = validPair?.0 ?? issued
        let validEnd   = validPair?.1 ?? Calendar.current.date(byAdding: .hour, value: 2, to: issued)!
        
        return WatchModel(
            number: wwNumber,
            title: title,
            link: link,
            issued: issued,
            validStart: validStart,
            validEnd: validEnd,
            summary: summary,
            alertType: .watch
        )
    }
    
    private func upsert(_ items: [WatchModel]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
