//
//  SPCConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation

struct SPCConvectiveOutlook: Identifiable, Hashable {
    let id: UUID              // usually the GUID or derived from it
    let title: String           // e.g., "Day 1 Convective Outlook"
    let link: URL               // link to full outlook page
    let published: Date         // pubDate
    let summary: String         // description / CDATA
    let day: Int?               // Day 1, 2, or 3 (parsed from title or GUID)
    let riskLevel: String?      // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
}

extension SPCConvectiveOutlook {
    static func from(rssItem: Item) -> SPCConvectiveOutlook? {
        guard
            let title = rssItem.title,
            let linkString = rssItem.link,
            let link = URL(string: linkString),
            let pubDateString = rssItem.pubDate,
            let summary = rssItem.description,
            let published = DateFormatter.rfc822.date(from: pubDateString)
        else {
            return nil
        }

        let day = title.contains("Day 1") ? 1 :
                  title.contains("Day 2") ? 2 :
                  title.contains("Day 3") ? 3 : nil

        let riskLevel = extractRiskLevel(from: summary)

        return SPCConvectiveOutlook(
            id: UUID(),
            title: title,
            link: link,
            published: published,
            summary: summary,
            day: day,
            riskLevel: riskLevel
        )
    }

    private static func extractRiskLevel(from text: String) -> String? {
        let levels = ["MRGL", "SLGT", "ENH", "MDT", "HIGH"]
        return levels.first { text.contains($0) }
    }
}

extension DateFormatter {
    static let rfc822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
