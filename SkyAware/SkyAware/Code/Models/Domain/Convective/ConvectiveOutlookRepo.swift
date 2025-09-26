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
    
    func refreshConvectiveOutlooks(using client: any SpcClient) async throws {
        let items = try await client.fetchOutlookItems()
        
        // Filters out some odd contents
        let outlooks = items
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
                                                       day: $0.day,
                                                       riskLevel: $0.riskLevel) }
        return dtos
    }
    
    func current() throws -> ConvectiveOutlookDTO? {
        let fetchDescriptor = FetchDescriptor<ConvectiveOutlook>()
        let outlooks: [ConvectiveOutlook] = try modelContext.fetch(fetchDescriptor)
        let outlook = outlooks.sorted { $0.published > $1.published }
        
        return ConvectiveOutlookDTO(title: outlook[0].title,
                                       link: outlook[0].link,
                                       published: outlook[0].published,
                                       summary: outlook[0].summary,
                                       day: outlook[0].day,
                                       riskLevel: outlook[0].riskLevel)
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
