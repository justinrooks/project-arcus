//
//  MDParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

enum MDParser {
    // Parse MD number from link (md####.html)
    static func parseMDNumber(from url: URL) -> Int? {
        let s = url.absoluteString
        guard
            let r = s.range(of: #"md(\d{3,4})\.html"#, options: .regularExpression),
            let m = try? NSRegularExpression(pattern: #"md(\d{3,4})\.html"#)
                .firstMatch(in: s, range: NSRange(r, in: s)),
            m.numberOfRanges == 2,
            let gr = Range(m.range(at: 1), in: s)
        else { return nil }
        return Int(s[gr])
    }
    
    // Parse the areas affected
    static func parseAreas(_ text: String) -> String {
        let reAreas   = try! Regex(#"(?is)Areas affected\.\.\.\s*(.*?)\s*(?=Concerning\.\.\.)"#)
        return first(text, reAreas) ?? ""
    }
    
    // Parse the summary and discussion
    static func parseSummary(_ text: String) -> String {
        let reSummary = try! Regex(#"(?is)SUMMARY\.\.\.\s*(.*?)\s*(?=DISCUSSION\.\.\.)"#)
        return first(text, reSummary) ?? ""
    }
    
    // TODO: MOVE OUT TO REUSE?
    // Parse Valid range (Z times) relative to issued date (UTC). Handles crossing 00Z boundary.
    static func parseValid(_ text: String, issued: Date) -> (Date, Date)? {
        let reValid = try! Regex(#"(?im)^\s*Valid\s+(\d{2})(\d{2})Z\s*-\s*(\d{2})(\d{2})Z\s*$"#)
        guard let m = text.firstMatch(of: reValid) else { return nil }
        let sH = Int(String(text[m.output[1].range!]))!
        let sM = Int(String(text[m.output[2].range!]))!
        let eH = Int(String(text[m.output[3].range!]))!
        let eM = Int(String(text[m.output[4].range!]))!

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // Build start on issued day in UTC
        let comps = cal.dateComponents(in: cal.timeZone, from: issued)
        let start = cal.date(from: DateComponents(calendar: cal,
                                                 timeZone: cal.timeZone,
                                                 year: comps.year,
                                                 month: comps.month,
                                                 day: comps.day,
                                                 hour: sH, minute: sM))!
        var end   = cal.date(from: DateComponents(calendar: cal,
                                                 timeZone: cal.timeZone,
                                                 year: comps.year,
                                                 month: comps.month,
                                                 day: comps.day,
                                                 hour: eH, minute: eM))!
        // If end before start, roll to next day
        if end < start { end = cal.date(byAdding: .day, value: 1, to: end)! }
        return (start, end)
    }

    // Parse watch probability + concerning line
    static func parseWatchFields(_ text: String) -> (String, String?) {
        var probability: String? = nil
        var concerningText: String? = nil

        // --- Probability of Watch Issuance ---
        if let pwoiMatch = text.firstMatch(of: try! Regex(#"(?im)Probability\ of\ Watch\ Issuance\.\.\.\s*([0-9]{1,3})\s*percent\b"#)) {
            if let range = pwoiMatch.output[1].range,
               let pct = Int(text[range]) {
                probability = String(min(max(pct, 0), 100))
            }
        }

        // --- Concerning line ---
        if let concerningMatch = text.firstMatch(of: try! Regex(#"(?im)Concerning\.\.\.\s*(.+)$"#)) {
            if let range = concerningMatch.output[1].range {
                let raw = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Clean up trailing spaces or extra dots
                concerningText = raw.replacingOccurrences(of: #"\s+\.\.\."#, with: "", options: .regularExpression)
            }
        }

        // --- Active watch form (Tornado/Severe Thunderstorm Watch #s) ---
        if let watchMatch = text.firstMatch(of: try! Regex(#"(?im)Concerning\.\.\.\s*(Tornado|Severe\ Thunderstorm)\s+Watch(?:es)?\s+([^\n]+)"#)) {
            if let typeRange = watchMatch.output[1].range,
               let numRange = watchMatch.output[2].range {
                let type = String(text[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let tail = String(text[numRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let ids = tail.matches(of: try! Regex(#"\d+"#)).compactMap { Int(String(tail[$0.range])) }
                let line = ids.isEmpty ? "\(type) Watch \(tail)" : "\(type) Watch \(ids.map(String.init).joined(separator: ", "))"
                concerningText = line
                if probability == nil {
                    probability = "Unlikely"
                }
            }
        }

        // --- Fallback if no probability found ---
        if probability == nil {
            if text.range(of: #"watch\s+unlikely"#, options: [.regularExpression, .caseInsensitive]) != nil {
                probability = "Unlikely"
            }
        }

        return (probability ?? "Unknown", concerningText)
    }

    // Parse wind mph: choose the upper bound when a range is provided
    static func parseWindMPH(_ text: String) -> Int? {
        let reWind = try! Regex(#"(?im)^\s*MOST PROBABLE PEAK WIND GUST\.\.\.\s*([0-9]{2,3})(?:\s*-\s*([0-9]{2,3}))?\s*(?:MPH|KT)\b.*$"#)
        guard let m = text.firstMatch(of: reWind) else { return nil }
        if let hiR = m.output[2].range { return Int(String(text[hiR])) }
        if let loR = m.output[1].range { return Int(String(text[loR])) }
        return nil
    }

    // Parse hail inches as Double? (modified)
    static func parseHailRange(_ text: String) -> Double? {
        let reHail = try! Regex(#"(?im)^\s*MOST PROBABLE PEAK HAIL SIZE\.\.\.\s*(?:UP TO\s*)?([0-9]+(?:\.[0-9]+)?)(?:\s*-\s*([0-9]+(?:\.[0-9]+)?))?\s*IN\b.*$"#)
        guard let m = text.firstMatch(of: reHail) else { return nil }
        let low = Double(String(text[m.output[1].range!]))!
        if let hiR = m.output[2].range {
            let high = Double(String(text[hiR]))!
            // When a range is provided, use the upper bound as the representative value
            return max(low, high)
        } else {
            // Single value or "UP TO" value: use that value directly
            return low
        }
    }

    // Tornado strength as free text (e.g., "UP TO 95 MPH", "EF1-2 possible")
    static func parseTornadoStrength(_ text: String) -> String? {
        let reTor = try! Regex(#"(?im)^\s*MOST PROBABLE PEAK TORNADO (?:INTENSITY|STRENGTH)\.\.\.\s*([^\n]+)$"#)
        return first(text, reTor)
    }
    
    // Utility: first capture helper
    private static func first(_ text: String, _ re: Regex<AnyRegexOutput>) -> String? {
        guard let m = text.firstMatch(of: re), let r = m.output[1].range else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
