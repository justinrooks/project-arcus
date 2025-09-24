//
//  ConvectiveOutlookDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

struct ConvectiveOutlookDTO: Sendable, Identifiable {
    let id: UUID    // usually the GUID or derived from it
    let title: String                   // e.g., "Day 1 Convective Outlook"
    let link: URL                       // link to full outlook page
    let published: Date                 // pubDate
    let summary: String                 // description / CDATA
    let day: Int?                       // Day 1, 2, or 3 (parsed from title or GUID)
    let riskLevel: String?              // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
//    let valid: String?
    
    init(title: String, link: URL, published: Date, summary: String, day: Int?, riskLevel: String?) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.published = published
        self.summary = summary
        self.day = day
        self.riskLevel = riskLevel
    }
}
