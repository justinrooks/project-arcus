//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation
import SwiftData

// TODO: Remove the riskLevel here
// TODO: Rename summary to fullText
// Without a migration of SwiftData, we'll have to remove/reinstall the app to avoid db errors.

@Model
final class ConvectiveOutlook {
    var id: UUID    // usually the GUID or derived from it
    @Attribute(.unique) var title: String                   // e.g., "Day 1 Convective Outlook" This allows upserts if contents change
    var link: URL                       // link to full outlook page
    var published: Date                 // pubDate
    var summary: String                 // description / CDATA
    var day: Int?                       // Day 1, 2, or 3 (parsed from title or GUID)
    var riskLevel: String?              // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
//    var issued: Date?                   // Date of issue from SPC, different than actual publish date
//    var validUntil: Date?               // Valid until ending date. don't need the start right now as we are using issued
    
    convenience init?(from dto: ConvectiveOutlookDTO) {
        self.init(title: dto.title,
                  link: dto.link,
                  published: dto.published,
                  summary: dto.summary,
                  day: dto.day,
                  riskLevel: dto.riskLevel)
    }
    
    init(title: String, link: URL, published: Date, summary: String, day: Int?, riskLevel: String?) {
        self.id = UUID()
        self.title = title
        self.link = link
        self.published = published
        self.summary = summary
        self.day = day
        self.riskLevel = riskLevel
        
//        let issDate = ConvectiveOutlook.getIssuedDate(from: summary)
//        let val = ConvectiveOutlook.getValidUntilDate(from: summary)
//        let clean = ConvectiveOutlook.stripHeader(from: summary)
    }
}
