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
    var id: UUID    // usually the GUID or derived from it
    @Attribute(.unique) var title: String                   // e.g., "Day 1 Convective Outlook" This allows upserts if contents change
    var link: URL                       // link to full outlook page
    var published: Date                 // pubDate
    var summary: String                 // description / CDATA
    var day: Int?                       // Day 1, 2, or 3 (parsed from title or GUID)
    var riskLevel: String?              // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
//    var issued: Date?                   // Date of issue from SPC, different than actual publish date
//    var validUntil: Date?               // Valid until ending date. don't need the start right now as we are using issued
    
    convenience init?(from rssItem: Item) {
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

        let riskLevel = "TBD"//extractRiskLevel(from: summary)

        self.init(title: title,
                  link: link,
                  published: published,
                  summary: summary,
                  day: day,
                  riskLevel: riskLevel)
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
    
    private static func getIssuedDate(from text: String) -> Date? {
        let issuedPattern = #"(?m)^\d{3,4} [AP]M [A-Z]{2,4} .+$"#
        
        guard
            let issuedMatch = try? NSRegularExpression(pattern: issuedPattern)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return nil
        }
        
        // Extract issued
        let issuedRange = Range(issuedMatch.range, in: text)!
        let issued = String(text[issuedRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return issued.fromRFC1123String()
    }
    
    private static func getValidUntilDate(from text: String) -> String {
        let validPattern  = #"(?m)^Valid \d{6}Z - \d{6}Z$"#
        
        guard
            let validMatch = try? NSRegularExpression(pattern: validPattern)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return ""
        }
        
        // Extract valid
        let validRange = Range(validMatch.range, in: text)!
        let valid = String(text[validRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return valid
    }
    
    private static func stripHeader(from text: String) -> String {
        // Regex for issued (time/date) and valid line
        let validPattern  = #"(?m)^Valid \d{6}Z - \d{6}Z$"#
        
        guard
            let validMatch = try? NSRegularExpression(pattern: validPattern)
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return ""
        }
        
        // Extract valid
        let validRange = Range(validMatch.range, in: text)!
        
        // Body = everything after the valid line
        let bodyStart = validRange.upperBound
        let body = text[bodyStart...].trimmingCharacters(in: .whitespacesAndNewlines)

        return body
    }
    
//    static func extractRiskLevel(from text: String) -> String? {
//        let levels = ["MRGL", "SLGT", "ENH", "MDT", "HIGH"]
//        return levels.first { text.contains($0) }
//    }
}


final class ConvectiveOutlookDTO: Sendable, Identifiable {
    let id: UUID    // usually the GUID or derived from it
    let title: String                   // e.g., "Day 1 Convective Outlook"
    let link: URL                       // link to full outlook page
    let published: Date                 // pubDate
    let summary: String                 // description / CDATA
    let day: Int?                       // Day 1, 2, or 3 (parsed from title or GUID)
    let riskLevel: String?              // Optional, e.g., "SLGT", "ENH", etc., if extracted from summary
//    let valid: String?
//    
    
    convenience init?(from rssItem: Item) {
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

        let riskLevel = "TBD"//extractRiskLevel(from: summary)

        self.init(id: UUID(),
                  title: title,
                  link: link,
                  published: published,
                  summary: summary,
                  day: day,
                  riskLevel: riskLevel)
    }
    
    init(id: UUID, title: String, link: URL, published: Date, summary: String, day: Int?, riskLevel: String?) {
        self.id = id
        self.title = title
        self.link = link
        self.published = published
        self.summary = summary
        self.day = day
        self.riskLevel = riskLevel
    }
}
