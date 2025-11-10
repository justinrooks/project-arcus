//
//  ConvectiveOutlookRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor ConvectiveOutlookRepo {
    private let logger = Logger.convectiveRepo
    private let parser: RSSFeedParser = RSSFeedParser()
    private let dtoParser: convictParser = convictParser()
    
    func refreshConvectiveOutlooks(using client: any SpcClient) async throws {
        let data = try await client.fetchRssData(for: .convective)

        guard let data else {
            logger.warning("No convective outlooks found")
            return
        }
                
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        
        guard let channel = rss.channel else {
            logger.warning("Error parsing convective channel items")
            return
        }
        
        // Filters out some odd contents
        let outlooks = channel.items
            .filter { ($0.title ?? "").contains(" Convective Outlook") }
            .compactMap { makeConvectiveOutlook(from: $0) }
        
        try upsert(outlooks)
        logger.debug("Parsed \(outlooks.count) outlook\(outlooks.count > 1 ? "s" : "") from SPC")
    }
    
    func fetchConvectiveOutlooks() throws -> [ConvectiveOutlookDTO] {
        let fetchDescriptor = FetchDescriptor<ConvectiveOutlook>()
        let outlooks: [ConvectiveOutlook] = try modelContext.fetch(fetchDescriptor)
        let dtos = outlooks.map { ConvectiveOutlookDTO(title: $0.title,
                                                       link: $0.link,
                                                       published: $0.published,
                                                       summary: $0.summary,
                                                       fullText: $0.summary,
                                                       day: $0.day,
                                                       riskLevel: $0.riskLevel) }
        return dtos
    }
    
    func current() throws -> ConvectiveOutlookDTO? {
        var fetchDescriptor = FetchDescriptor<ConvectiveOutlook>(
            // Optional: Add a predicate if you want to filter results before sorting
            // predicate: #Predicate { $0.name == "Specific Name" },
            
            // 2. Sort by your date property in descending order
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        
        // 3. Limit the fetch to only one result (the most recent)
        fetchDescriptor.fetchLimit = 1
        
        guard let outlook = try modelContext.fetch(fetchDescriptor).first else { return nil }
        
//        let t = ConvectiveOutlook.sampleOutlooks.last!
        
        let test: coDTO = dtoParser.makeDto(from: outlook)
        
        let y = ConvectiveParser.stripHeader(from: outlook.summary)
        
//        logger.debug(test.discussion)
        
        return ConvectiveOutlookDTO(title: outlook.title,
                                    link: outlook.link,
                                    published: outlook.published,
                                    summary: test.summary ?? "No summary found",
                                    fullText: y,
                                    day: outlook.day,
                                    riskLevel: outlook.riskLevel)
    }
    
    func purge(asOf now: Date = .init()) throws {
        // Compute cutoff as 2 days before the provided `now`
        let cutoff = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        logger.info("Purging convective outlooks older than \(cutoff, privacy: .public)")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<ConvectiveOutlook> { $0.published < cutoff }
        var desc = FetchDescriptor<ConvectiveOutlook>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count) to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Convective outlooks purged")
    }
    
    private func upsert(_ items: [ConvectiveOutlook]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    private func makeConvectiveOutlook(from rssItem: Item) -> ConvectiveOutlook? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else { return nil }
        
        let day = title.contains("Day 1") ? 1 :
        title.contains("Day 2") ? 2 :
        title.contains("Day 3") ? 3 : nil
        
        let riskLevel = "TBD"//extractRiskLevel(from: summary)
        
        return ConvectiveOutlook(
            title: title,
            link: link,
            published: published,
            summary: summary,
            day: day,
            riskLevel: riskLevel)
    }
}
