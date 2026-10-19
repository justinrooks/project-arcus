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
    private let logger = Logger.reposConvectiveOutlook
    private let parser: RSSFeedParser = RSSFeedParser()
    private let outlookParser = OutlookParser()
    
    func refreshConvectiveOutlooks(
        using client: any SpcClient,
        shouldCommit: @Sendable () async -> Bool = { true }
    ) async throws -> HTTPResponse.Source {
        let response = try await client.fetchRssResponse(for: .convective)
        try Task.checkCancellation()
        guard let data = response.data else { throw SpcError.missingData }
                
        guard let rss = try parser.parse(data: data) else {
            throw SpcError.parsingError
        }
        
        guard let channel = rss.channel else {
            logger.error("Convective RSS parsed without a channel")
            throw SpcError.parsingError
        }
        
        let recognizedOutlooks = channel.items
            .filter { Self.supportedDay(for: $0.title ?? "") != nil }
        guard recognizedOutlooks.isEmpty == false else {
            logger.error("Convective RSS contained no recognized outlooks")
            throw SpcError.parsingError
        }
        let outlooks = recognizedOutlooks.compactMap { makeConvectiveOutlook(from: $0) }
        logDayCounts(outlooks, stage: "recognized", source: response.source)

        guard outlooks.count == recognizedOutlooks.count else {
            logger.error("Convective RSS contained malformed recognized outlooks")
            throw SpcError.parsingError
        }
        
        guard response.source == .live || response.source == .cacheRevalidated304 else {
            logger.notice("Ignored non-authoritative convective outlook response source=\(String(describing: response.source), privacy: .public)")
            return response.source
        }

        guard await shouldCommit() else { throw CancellationError() }
        try replaceAcceptedCollection(with: outlooks)
        logDayCounts(outlooks, stage: "accepted", source: response.source)
        logger.debug("Persisted convective outlook refresh count=\(outlooks.count, privacy: .public)")
        return response.source
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

    func collectionSnapshot(for day: Int? = nil) throws -> ConvectiveOutlookCollectionSnapshot {
        let rows = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        return ConvectiveOutlookCollectionSnapshot(rows: rows, day: day)
    }
    
    func current() throws -> ConvectiveOutlookDTO? {
        var fetchDescriptor = FetchDescriptor<ConvectiveOutlook>(
            predicate: #Predicate { $0.day != 0 },
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
        
        let rows = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        guard rows.contains(where: { $0.published < cutoff }) else { return }
        // A partial purge would make the remaining rows look like a newly accepted collection.
        for row in rows { modelContext.delete(row) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        
        logger.info("Convective outlooks purged")
    }
    
    // MARK: Helpers
    private static func supportedDay(for title: String) -> Int? {
        (1...3).first { day in
            title.range(
                of: #"\bDay \#(day) (?:Convective|Severe Thunderstorm) Outlook$"#,
                options: .regularExpression
            ) != nil
        }
    }

    private func logDayCounts(_ outlooks: [ConvectiveOutlook], stage: String, source: HTTPResponse.Source) {
        let counts = (1...3).map { day in outlooks.filter { $0.day == day }.count }
        logger.info("Convective RSS stage=\(stage, privacy: .public) source=\(String(describing: source), privacy: .public) day1=\(counts[0], privacy: .public) day2=\(counts[1], privacy: .public) day3=\(counts[2], privacy: .public)")
    }

    private func replaceAcceptedCollection(with items: [ConvectiveOutlook]) throws {
        let previous = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        for row in previous { modelContext.delete(row) }
        for item in items {
            modelContext.insert(item)
        }
        if let latestPublished = items.map(\.published).max() {
            modelContext.insert(ConvectiveOutlook.collectionMarker(published: latestPublished))
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
    
    private func makeConvectiveOutlook(from rssItem: Item) -> ConvectiveOutlook? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let scheme = link.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            link.host != nil,
            let pubDateString = rssItem.pubDate,
            let fullText = rssItem.description,
            let published = pubDateString.fromRFC822()
        else { return nil }
        
        // Derived Properties
        let day = Self.supportedDay(for: title)
        
        let summary = outlookParser.extractSummary(fullText) ?? "Summary not found"
        let issued = outlookParser.extractIssuedDate(fullText)
        let validUntil = outlookParser.extractValidUntilDate(fullText)
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
