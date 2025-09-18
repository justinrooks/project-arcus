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
    private var context: ModelContext { modelExecutor.modelContext }
    private let logger = Logger.convectiveRepo
    
    func refreshConvectiveOutlooks() async throws {
        let client = SpcClient()
        let items = try await client.fetchOutlookItems()
        
        // Filters out some odd contents
        let outlooks = items
            .filter { ($0.title ?? "").contains(" Convective Outlook") }
            .compactMap { makeConvectiveDto(from: $0) }
        
        try await upsertConvectiveOutlooks(outlooks)
        logger.debug("Parsed \(outlooks.count) outlook\(outlooks.count > 1 ? "s" : "") from SPC")
    }
    
    func fetchConvectiveOutlooks() throws -> [ConvectiveOutlookDTO] {
        let fetchDescriptor = FetchDescriptor<ConvectiveOutlook>()
        let outlooks: [ConvectiveOutlook] = try context.fetch(fetchDescriptor)
        let dtos = outlooks.map { ConvectiveOutlookDTO(title: $0.title,
                                                      link: $0.link,
                                                      published: $0.published,
                                                      summary: $0.summary,
                                                      day: $0.day,
                                                      riskLevel: $0.riskLevel) }
        return dtos
    }
    
    private func makeConvectiveDto(from rssItem: Item) -> ConvectiveOutlookDTO? {
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
        
        return ConvectiveOutlookDTO(
                  title: title,
                  link: link,
                  published: published,
                  summary: summary,
                  day: day,
                  riskLevel: riskLevel)
    }
    
    private func upsertConvectiveOutlooks(_ outlooks: [ConvectiveOutlookDTO]) async throws {
        _ = try outlooks.map {
            guard let m = ConvectiveOutlook(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(m)
        }
        
        try context.save()
    }
}
