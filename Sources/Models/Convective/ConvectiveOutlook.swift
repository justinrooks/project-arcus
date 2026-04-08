//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation
import SwiftData

@Model
final class ConvectiveOutlook {
    var id: UUID                            // usually the GUID or derived from it
    @Attribute(.unique) var title: String   // e.g., "Day 1 Convective Outlook" This allows upserts if contents change
    var link: URL                           // link to full outlook page
    var published: Date                     // pubDate
    var fullText: String?                   // description / CDATA
    
    // MARK: Derived Data - Keep it optional until it can be backfilled
    var summary: String                     // This will become the derived value, right now its all the text.
    var riskLevel: String?                  // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
    var issued: Date?                       // Date of issue from SPC, different than actual publish date
    var validUntil: Date?                   // Valid until ending date. don't need the start right now as we are using issued
    var day: Int?                           // Day 1, 2, or 3 (parsed from title or GUID)
        
    init(
        title: String,
        link: URL,
        published: Date,
        fullText: String,
        summary: String,
        day: Int?,
        riskLevel: String?,
        issued: Date,
        validUntil: Date
    ) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.published = published
        self.fullText = fullText
        
        // Derived
        self.summary = summary
        self.riskLevel = riskLevel
        self.issued = issued
        self.validUntil = validUntil
        self.day = day
        
    }
}
