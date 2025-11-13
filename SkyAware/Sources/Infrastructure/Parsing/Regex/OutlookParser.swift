//
//  OutlookParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/11/25.
//

import Foundation

struct OutlookParser: Sendable {
    private enum RX {
        static let opts: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    }
    // 4. Extract any Update text
    
    func extractSummary(_ text: String) -> String? {
        summaryHeaderRegex.firstMatch(in: text)?.captured("summary", in: text)
    }
    
    func extractIssuedDate(_ text: String) -> Date? {
        let pattern = #"\b(?<time>\d{3,4})\s*(?<ampm>AM|PM)\s+(?<tz>[A-Z]{2,4})\s+(?<dow>[A-Za-z]{3})\s+(?<mon>[A-Za-z]{3})\s+(?<day>\d{1,2})\s+(?<year>\d{4})\b"#

        if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let issued = String(text[match])
            
            return issued.parseAsIssuedDate()
        }

        return nil
    }
    
    /// Extracts the valid until date from the outlook
    /// - Parameter text: the full outlook text
    /// - Returns: The date that the outlook is valid until, if found
    func extractValidUntilDate(_ text: String) -> Date? {
        guard let m = validRegex.firstMatch(in: text),
              let _ = m.captured("start", in: text), // Ignore for now, may need later
              let end   = m.captured("end", in: text)
        else { return nil }

        return end.parseSPCValidTime()
    }
    
    func extractRiskLevel(_ text: String) -> String? {
        // TODO: Figure out how/if we are going to extract this
        return "MDT"
    }
    
    func stripHeader(from text: String) -> String {
        // Regex for issued (time/date) and valid line
        //let validPattern  = #"(?m)^Valid \d{6}Z - \d{6}Z$"#
        let validPattern = #"\bvalid\s+(?<start>\d{6})\s*z?\s*-\s*(?<end>\d{6})\s*z?\b"#
        
        guard
            let validMatch = try? NSRegularExpression(pattern: validPattern, options: RX.opts)
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
    
    /// Looks for the no severe text markers in the doc
    /// - Parameter text: the entire outlook to parse
    /// - Returns: true if there is no risk of severe reported
    func extractIsQuietNoSevere(_ text: String) -> Bool {
        quietNoSevereRegex.firstMatch(in: text) != nil
    }
    
    /// Looks for the no thunderstorm text markers in the doc
    /// - Parameter text: the entire outlook to parse
    /// - Returns: true if there is no risk of thunderstorm reported
    func extractIsQuietNoThunder(_ text: String) -> Bool {
        quietNoThunderRegex.firstMatch(in: text) != nil
    }
    
    // MARK: Regex patterns
    private let summaryHeaderRegex = try! NSRegularExpression(
        pattern: #"\.\.\.\s*SUMMARY\s*\.\.\.\s*(?<summary>.*?)(?=(?:[\t\r\n ]*)\.\.\.|$)"#, options: RX.opts
    )
    
    private let validRegex = try! NSRegularExpression(
        pattern: #"\bvalid\s+(?<start>\d{6})\s*z?\s*-\s*(?<end>\d{6})\s*z?\b"#, options: RX.opts
    )
    
    private let quietNoSevereRegex = try! NSRegularExpression(
        pattern: #"\bno\s+severe\s+thunderstorm\s+areas\s+forecast\b"#, options: RX.opts
    )
    
    private let quietNoThunderRegex = try! NSRegularExpression(
        pattern: #"\bno\s+thunderstorm\s+areas\s+forecast\b"#, options: RX.opts
    )
    
    private let riskHeadlineRegex = try! NSRegularExpression(
        pattern: #"^\s*there\s+is\s+a\s+(?<level>MARGINAL|SLIGHT|ENHANCED|MODERATE|HIGH)\s+risk\s+of\s+severe\s+thunderstorms\s+(?<region>.+?)\s*$"#,
        options: RX.opts
    )
}

private extension NSRegularExpression {
    func firstMatch(in s: String) -> NSTextCheckingResult? {
        let ns = s as NSString
        return firstMatch(in: s, range: NSRange(location: 0, length: ns.length))
    }
}

private extension NSTextCheckingResult {
    func captured(_ name: String, in s: String) -> String? {
        let ns = s as NSString
        let r = range(withName: name)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }
}
