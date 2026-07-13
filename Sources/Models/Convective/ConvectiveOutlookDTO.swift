//
//  ConvectiveOutlookDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

struct ConvectiveOutlookDTO: Sendable, Identifiable, Hashable {
    let id: String             // stable feed-backed identity for SwiftUI diffing
    let title: String          // e.g., "Day 1 Convective Outlook"
    let link: URL              // link to full outlook page
    let published: Date        // pubDate
    let summary: String        // just the parsed summary section
    let fullText: String       // The entire outlook
    let day: Int?              // Day 1, 2, or 3 (parsed from title or GUID)
    let riskLevel: String?     // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
    let issued: Date?
    let validUntil: Date?
    
    init(title: String, link: URL, published: Date, summary: String, fullText: String, day: Int?, riskLevel: String?, issued: Date?, validUntil: Date?) {
        self.id = "\(title)|\(published.ISO8601Format())"
        self.title = title
        self.link = link
        self.published = published
        self.summary = summary
        self.fullText = fullText
        self.day = day
        self.riskLevel = riskLevel
        self.issued = issued
        self.validUntil = validUntil
    }
}

extension ConvectiveOutlookDTO {
    var cleanText: String? {
        let parser = OutlookParser()
        return parser.stripHeader(from: fullText)
    }
}
