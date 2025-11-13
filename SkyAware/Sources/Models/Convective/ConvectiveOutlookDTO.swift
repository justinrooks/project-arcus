//
//  ConvectiveOutlookDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

struct ConvectiveOutlookDTO: Sendable, Identifiable, Hashable {
    let id: UUID               // usually the GUID or derived from it
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
        self.id = UUID()
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
//extension String {
//    /// Truncates to the first N complete sentences, adds ellipsis if truncated
//    func truncateToSentences(count: Int) -> String {
//        // Split on sentence boundaries (period + space, exclamation, question mark)
//        let pattern = "(?<=[.!?])\\s+"
//        guard let regex = try? NSRegularExpression(pattern: pattern) else {
//            // Fallback: simple character truncation if regex fails
//            return self.count > 150 ? String(self.prefix(150)) + "..." : self
//        }
//        
//        let range = NSRange(location: 0, length: self.utf16.count)
//        let matches = regex.matches(in: self, range: range)
//        
//        // If we have fewer sentences than requested, return full text
//        guard matches.count >= count else {
//            return self
//        }
//        
//        // Get the range up to the Nth sentence boundary
//        let nthMatch = matches[count - 1]
//        let endIndex = self.index(self.startIndex, offsetBy: nthMatch.range.location)
//        let truncated = String(self[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        // Only add ellipsis if we actually truncated
//        return truncated.count < self.count ? truncated + "..." : truncated
//    }
//}


@available(*, deprecated, message: "Use the ConvectiveOutlookDTO instead")
struct coDTO: Sendable, Equatable {
    struct Valid: Sendable, Equatable {
        var startZ: String
        var endZ: String
    }
    
    enum RiskLevel: String, Sendable { case marginal, slight, enhanced, moderate, high }
    struct RiskHeadline: Sendable, Equatable {
        var level: RiskLevel
        var regionRaw: String
        var rawHeader: String
    }
    struct Update: Sendable, Equatable { var hourZ: String; var text: String }
    struct RegionalNote: Sendable, Equatable { var title: String; var text: String }
    
    var issuedLocal: String?
    var validUTC: Valid?
    var summary: String?
    var discussion: String?
    var previousDiscussion: String?
    var updates: [Update] = []
    var riskHeadlines: [RiskHeadline] = []
    var quietNoThunder: Bool = false
    var quietNoSevere: Bool = false
    var regionalSubsections: [RegionalNote] = []
}
