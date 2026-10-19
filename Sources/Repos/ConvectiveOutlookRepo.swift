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
        asOf referenceDate: Date? = nil,
        shouldCommit: @Sendable () async -> Bool = { true }
    ) async throws -> HTTPResponse.Source {
        var incoming: [ConvectiveOutlookDTO] = []
        var acceptedSources: [HTTPResponse.Source] = []
        var lastSource: HTTPResponse.Source?
        var acquisitionError: (any Error)?
        // RSS is a publication feed, not a complete Day 1–3 snapshot. Current pages bootstrap
        // omitted days; RSS contributes available earlier issuances. Stage everything before saving.
        do {
            let response = try await client.fetchRssResponse(for: .convective)
            lastSource = response.source
            guard let data = response.data, let channel = try parser.parse(data: data)?.channel else {
                throw SpcError.parsingError
            }
            let recognized = channel.items.filter { Self.supportedDay(for: $0.title ?? "") != nil }
            let items = recognized.compactMap { makeConvectiveOutlook(from: $0)?.dto }
            guard !recognized.isEmpty, items.count == recognized.count else { throw SpcError.parsingError }
            logDayCounts(items, stage: "recognized", source: response.source)
            if response.source == .live || response.source == .cacheRevalidated304 {
                incoming += items
                acceptedSources.append(response.source)
            }
        } catch is CancellationError { throw CancellationError() }
        catch { acquisitionError = error }

        for day in [SPCForecastDay.day1, .day2, .day3] {
            try Task.checkCancellation()
            do {
                let response = try await client.fetchCurrentOutlookResponse(for: day)
                lastSource = response.source
                guard response.source == .live || response.source == .cacheRevalidated304 else { continue }
                guard let data = response.data else { throw SpcError.missingData }
                incoming.append(try SPCDiscussionAcceptance.parseCurrent(data, day: day))
                acceptedSources.append(response.source)
            } catch is CancellationError { throw CancellationError() }
            catch {
                logger.notice("Current SPC discussion unavailable day=\(day.rawValue, privacy: .public)")
                if acquisitionError == nil { acquisitionError = error }
            }
        }
        try Task.checkCancellation()
        guard !acceptedSources.isEmpty else {
            if let lastSource, lastSource == .cacheFallback || lastSource == .localCache { return lastSource }
            throw acquisitionError ?? SpcError.missingData
        }
        guard await shouldCommit() else { throw CancellationError() }
        try Task.checkCancellation()
        // Evaluate at commit time, not request start: a slow older request must not
        // classify a newer accepted issuance as future data and remove it.
        let now = referenceDate ?? .now
        guard !SPCDiscussionAcceptance.retained(incoming, asOf: now).isEmpty else { throw SpcError.parsingError }
        // Re-read after the final await: an older concurrent refresh cannot replace a newer period.
        let previous = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        let priorAccepted = previous.contains(where: \.isCollectionMarker)
            ? previous.filter { !$0.isCollectionMarker }.map(\.dto) : []
        let accepted = SPCDiscussionAcceptance.retained(priorAccepted + incoming, asOf: now)
        try replaceAcceptedCollection(with: accepted.map(Self.model))
        let source: HTTPResponse.Source = acceptedSources.contains(.live) ? .live : .cacheRevalidated304
        logDayCounts(accepted, stage: "accepted", source: source)
        return source
    }

    func fetchConvectiveOutlooks(for day: Int = 1, asOf now: Date = .now) throws -> [ConvectiveOutlookDTO] {
        let rows = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        return SPCDiscussionAcceptance.retained(rows.filter { !$0.isCollectionMarker }.map(\.dto), asOf: now)
            .filter { $0.day == day }
    }

    func collectionSnapshot(for day: Int? = nil, asOf now: Date = .now) throws -> ConvectiveOutlookCollectionSnapshot {
        let rows = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        return ConvectiveOutlookCollectionSnapshot(rows: rows, day: day, asOf: now)
    }

    func current(asOf now: Date = .now) throws -> ConvectiveOutlookDTO? {
        let rows = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        return SPCDiscussionAcceptance.retained(rows.filter { !$0.isCollectionMarker }.map(\.dto), asOf: now).first
    }

    func purge(asOf now: Date = .now) throws {
        let rows = try modelContext.fetch(FetchDescriptor<ConvectiveOutlook>())
        guard !rows.isEmpty else { return }
        let accepted = SPCDiscussionAcceptance.retained(rows.filter { !$0.isCollectionMarker }.map(\.dto), asOf: now)
        if rows.contains(where: \.isCollectionMarker) {
            try replaceAcceptedCollection(with: accepted.map(Self.model))
        } else {
            let retainedIDs = Set(accepted.map(\.id))
            for row in rows where !retainedIDs.contains(row.dto.id) { modelContext.delete(row) }
            do { try modelContext.save() } catch { modelContext.rollback(); throw error }
        }
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

    private func logDayCounts(_ outlooks: [ConvectiveOutlookDTO], stage: String, source: HTTPResponse.Source) {
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
    
    private static func model(_ dto: ConvectiveOutlookDTO) -> ConvectiveOutlook {
        ConvectiveOutlook(
            title: dto.title, link: dto.link, published: dto.issued ?? dto.published,
            fullText: dto.fullText, summary: dto.summary, day: dto.day,
            riskLevel: dto.riskLevel, issued: dto.issued, validUntil: dto.validUntil
        )
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
        let validity = issued.flatMap { SPCDiscussionAcceptance.validity(in: fullText, issued: $0) }
        // A source validity line that cannot be interpreted is malformed, not missing metadata.
        let hasValidityHeader = fullText.range(of: #"(?m)^\s*Valid\s+\d"#, options: .regularExpression) != nil
        guard !hasValidityHeader || validity != nil else { return nil }
        let validUntil = validity?.end
        let riskLevel:String? = outlookParser.extractRiskLevel(fullText)
        
        return ConvectiveOutlook(
            title: issued.map { "\(title) — \($0.ISO8601Format())" } ?? title,
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

/// Source metadata and bounded retention for the single canonical discussion repository.
enum SPCDiscussionAcceptance {
    static let maximumIssuancesPerDay = 12
    static let legacyMaximumAge: TimeInterval = 48 * 3600

    static func validity(in text: String, issued: Date) -> DateInterval? {
        guard let range = text.range(of: #"\bValid \d{6}Z - \d{6}Z\b"#, options: .regularExpression) else {
            return nil
        }
        let tokens = text[range].split(separator: " ")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        func dates(_ token: Substring, around anchor: Date) -> [Date] {
            let digits = String(token.prefix(6))
            guard let day = Int(digits.prefix(2)), let hour = Int(digits.dropFirst(2).prefix(2)),
                  let minute = Int(digits.suffix(2)), (1...31).contains(day),
                  (0...23).contains(hour), (0...59).contains(minute) else { return [] }
            return [-1, 0, 1].compactMap { offset in
                guard let month = calendar.date(byAdding: .month, value: offset, to: anchor) else { return nil }
                var components = calendar.dateComponents([.year, .month], from: month)
                components.day = day
                components.hour = hour
                components.minute = minute
                guard let date = calendar.date(from: components), calendar.component(.day, from: date) == day else {
                    return nil
                }
                return date
            }
        }
        guard let start = dates(tokens[1], around: issued)
            .filter({ (-86400...259200).contains($0.timeIntervalSince(issued)) })
            .min(by: { abs($0.timeIntervalSince(issued)) < abs($1.timeIntervalSince(issued)) }),
              let end = dates(tokens[3], around: start)
            .filter({ $0 > start && $0.timeIntervalSince(start) <= 36 * 3600 }).min() else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func parseCurrent(_ data: Data, day: SPCForecastDay) throws -> ConvectiveOutlookDTO {
        guard let html = String(data: data, encoding: .utf8),
              let text = RSSFeedParser().extractPreText(from: html),
              let titleRange = text.range(of: #"\bDay \#(day.rawValue) (?:Convective|Severe Thunderstorm) Outlook\b"#,
                                          options: .regularExpression),
              let issued = OutlookParser().extractIssuedDate(text),
              let validity = validity(in: text, issued: issued),
              let summary = OutlookParser().extractSummary(text),
              !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let link = URL(string: "https://www.spc.noaa.gov/products/outlook/day\(day.rawValue)otlk.html") else {
            throw SpcError.parsingError
        }
        return ConvectiveOutlookDTO(
            title: "\(text[titleRange]) — \(issued.ISO8601Format())", link: link,
            published: issued, summary: summary,
            fullText: text, day: day.rawValue, riskLevel: nil, issued: issued, validUntil: validity.end
        )
    }

    static func retained(_ items: [ConvectiveOutlookDTO], asOf now: Date) -> [ConvectiveOutlookDTO] {
        // Reconstruct legacy cached metadata from the source body. Older builds anchored
        // validity to the read month; never display that derived date as source truth.
        let normalized = items.map { item in
            guard let issued = item.issued, let interval = validity(in: item.fullText, issued: issued) else { return item }
            return ConvectiveOutlookDTO(
                title: item.title, link: item.link, published: issued, summary: item.summary,
                fullText: item.fullText, day: item.day, riskLevel: item.riskLevel,
                issued: issued, validUntil: interval.end
            )
        }
        var result: [ConvectiveOutlookDTO] = []
        for day in 1...3 {
            let candidates = normalized.filter { item in
                guard item.day == day else { return false }
                let issued = item.issued ?? item.published
                guard issued <= now else { return false }
                if let end = expiry(item) { return end > now && end.timeIntervalSince(issued) <= 4 * 86400 }
                return now.timeIntervalSince(issued) < legacyMaximumAge
            }
            // A forecast day is a source role. A later validity period supersedes the old role,
            // even if that older period has not ended yet. Never derive the role from local dates.
            let latestEnd = candidates.compactMap(expiry).max()
            let period = candidates.filter { latestEnd == nil || expiry($0) == latestEnd }
            var identities = Set<Date>()
            var titles = Set<String>()
            result += period.sorted(by: ordered).filter {
                identities.insert($0.issued ?? $0.published).inserted && titles.insert($0.title).inserted
            }
                .prefix(maximumIssuancesPerDay)
        }
        return result.sorted(by: ordered)
    }

    private static func expiry(_ item: ConvectiveOutlookDTO) -> Date? {
        if let issued = item.issued, let interval = validity(in: item.fullText, issued: issued) { return interval.end }
        return item.validUntil
    }

    private static func ordered(_ lhs: ConvectiveOutlookDTO, _ rhs: ConvectiveOutlookDTO) -> Bool {
        let left = lhs.issued ?? lhs.published
        let right = rhs.issued ?? rhs.published
        if left != right { return left > right }
        if lhs.title != rhs.title { return lhs.title > rhs.title }
        if lhs.fullText != rhs.fullText { return lhs.fullText > rhs.fullText }
        return lhs.link.absoluteString > rhs.link.absoluteString
    }
}
