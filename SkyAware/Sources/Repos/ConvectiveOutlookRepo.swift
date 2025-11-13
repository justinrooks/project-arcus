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
    private let outlookParser = OutlookParser()
    
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
    
    func fetchConvectiveOutlooks(for day:Int = 1) throws -> [ConvectiveOutlookDTO] {
        let pred = #Predicate<ConvectiveOutlook> { outlook in
            outlook.day == day
        }
        
        let outlooks: [ConvectiveOutlook] = try modelContext.fetch(
            FetchDescriptor<ConvectiveOutlook>(
                predicate: pred,
                sortBy: [.init(\.published,order: .reverse)]
            )
        )
        
        let dtos = outlooks.map { ConvectiveOutlookDTO(title: $0.title,
                                                       link: $0.link,
                                                       published: $0.published,
                                                       summary: $0.summary,
                                                       fullText: $0.fullText ?? "Full text not yet parsed",
                                                       day: $0.day,
                                                       riskLevel: $0.riskLevel,
                                                       issued: $0.issued,
                                                       validUntil: $0.validUntil) }
        return dtos
    }
    
    func current() throws -> ConvectiveOutlookDTO? {
        var fetchDescriptor = FetchDescriptor<ConvectiveOutlook>(
            sortBy: [.init(\.published, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = 1
        
        guard let outlook = try modelContext.fetch(fetchDescriptor).first else { return nil }

        return ConvectiveOutlookDTO(title: outlook.title,
                                    link: outlook.link,
                                    published: outlook.published,
                                    summary: outlook.summary,
                                    fullText: outlook.fullText ?? "Full text not yet parsed",
                                    day: outlook.day,
                                    riskLevel: outlook.riskLevel,
                                    issued: outlook.issued,
                                    validUntil: outlook.validUntil)
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
    
    // MARK: Helpers
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
            let fullText = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else { return nil }
        
        // Derived Properties
        let day = title.contains("Day 1") ? 1 :
            title.contains("Day 2") ? 2 :
            title.contains("Day 3") ? 3 : nil
        
        let summary = outlookParser.extractSummary(fullText) ?? "Summary not found"
        let issued = outlookParser.extractIssuedDate(fullText) ?? Date()
        let validUntil = outlookParser.extractValidUntilDate(fullText) ?? Date()
        let riskLevel:String? = outlookParser.extractRiskLevel(fullText)
        
        return ConvectiveOutlook(
            title: title,
            link: link,
            published: published,
            fullText: fullText,
            summary: summary,
            day: day,
            riskLevel: riskLevel,
            issued: issued,
            validUntil: validUntil)
    }
}
