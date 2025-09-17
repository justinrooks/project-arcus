//
//  ConvectiveParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

enum ConvectiveParser {
    static func getIssuedDate(from text: String) -> Date? {
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
    
    static func getValidUntilDate(from text: String) -> String {
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
    
    static func stripHeader(from text: String) -> String {
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
