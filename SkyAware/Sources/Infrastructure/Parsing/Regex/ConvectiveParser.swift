//
//  ConvectiveParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation

@available(*, deprecated, message: "Use the OutlookParser instead")
struct convictParser: Sendable {
    func makeDto(from item: ConvectiveOutlook) -> coDTO {
        let text = item.summary
        var dto = coDTO()
        
        dto.validUTC = extractValid(text)
        dto.issuedLocal = extractIssued(text)
        dto.summary = extractSummary(text)
        
        let sections = sliceEllipsisSections(text)
        
        for sec in sections {
            let labelNorm = normalizeHeader(sec.label)
            let body = sec.body.trimmed()
            
            if quietNoSevereRegex.firstMatch(in: labelNorm) != nil { dto.quietNoSevere = true; continue }
            if quietNoThunderRegex.firstMatch(in: labelNorm) != nil { dto.quietNoThunder = true; continue }
            
            if let m = updateHeaderRegex.firstMatch(in: labelNorm),
               let hour = m.captured("hour", in: labelNorm) {
                dto.updates.append(.init(hourZ: hour, text: body))
                continue
            }
            
            //            if summaryHeaderRegex.firstMatch(in: labelNorm) != nil {
            //                dto.summary = (dto.summary?.isEmpty == false) ? [dto.summary!, body].joined(separator: "\n\n") : body
            //                continue
            //            }
            
            if discussionHeaderRegex.firstMatch(in: labelNorm) != nil {
                dto.discussion = (dto.discussion?.isEmpty == false) ? [dto.discussion!, body].joined(separator: "\n\n") : body
                continue
            }
            
            if let m = riskHeadlineRegex.firstMatch(in: labelNorm),
               let lvl = m.captured("level", in: labelNorm)?.uppercased(),
               let region = m.captured("region", in: labelNorm) {
                if let enumLevel = mapRiskLevel(lvl) {
                    dto.riskHeadlines.append(.init(level: enumLevel, regionRaw: region.trimmed(), rawHeader: sec.label))
                    continue
                }
            }
            
            if !labelNorm.isEmpty {
                dto.regionalSubsections.append(.init(title: sec.label.trimmed(), text: body))
            }
        }
        
        if let prev = capturePrevDiscussion(text) {
            dto.previousDiscussion = prev
        }
        
        return dto
    }
    
    // MARK: - Regex compilation
    
    private enum RX {
        static let opts: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    }
    
    private let sectionSlicerRegex = try! NSRegularExpression(
        pattern: #"\.\.\.\s*(?<label>[^.][^.]*?)\s*\.\.\.\s*(?<body>.*?)(?=\s*\.\.\.\s*[^.][^.]*?\s*\.\.\.|$)"#,
        options: RX.opts
    )
    //    private let sectionSlicerRegex = try! NSRegularExpression(
    //        pattern: #"\.\.\.\s*(?<label>.+)\s*\.\.\.\s*(?<body>.*?)(?=\s*\.\.\.\s*.+\s*\.\.\.|$)"#,
    //        options: RX.opts
    //    )
    
    private let updateHeaderRegex = try! NSRegularExpression(
        pattern: #"^\s*(?<hour>\d{2})\s*z\s+update\s*$"#, options: RX.opts
    )
    
    private let summaryHeaderRegex = try! NSRegularExpression(
        //        pattern: #"^\s*summary\s*$"#, options: RX.opts
        pattern: #"\.\.\.\s*SUMMARY\s*\.\.\.\s*(?<summary>.*?)(?=(?:[\t\r\n ]*)\.\.\.|$)"#, options: RX.opts
    )
    
    private let issuedExtractorRegex = try! NSRegularExpression(
      pattern: #"(?i)Norman\s+OK(?:\s+|\\n+)(?<hhmm>\d{3,4})\s*(?<ampm>AM|PM)\s+(?<tz>C[SD]T)\s+(?<dow>Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+(?<mon>Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(?<day>\d{1,2})\s+(?<year>\d{4})"#
//      options: nil
    )
    
    
    private let discussionHeaderRegex = try! NSRegularExpression(
        pattern: #"^\s*(synopsis(?:\s+and\s+discussion)?|discussion)\s*$"#, options: RX.opts
    )
    
    private let riskHeadlineRegex = try! NSRegularExpression(
        pattern: #"^\s*there\s+is\s+a\s+(?<level>MARGINAL|SLIGHT|ENHANCED|MODERATE|HIGH)\s+risk\s+of\s+severe\s+thunderstorms\s+(?<region>.+?)\s*$"#,
        options: RX.opts
    )
    
    private let quietNoSevereRegex = try! NSRegularExpression(
        pattern: #"\bno\s+severe\s+thunderstorm\s+areas\s+forecast\b"#, options: RX.opts
    )
    
    private let quietNoThunderRegex = try! NSRegularExpression(
        pattern: #"\bno\s+thunderstorm\s+areas\s+forecast\b"#, options: RX.opts
    )
    
    private let validRegex = try! NSRegularExpression(
        pattern: #"\bvalid\s+(?<start>\d{6})\s*z?\s*-\s*(?<end>\d{6})\s*z?\b"#, options: RX.opts
    )
    
    private let issuedRegex = try! NSRegularExpression(
        pattern: #"\b(?<issued>\d{3,4}\s*[AP]M\s+[A-Z]{2,4}\s+\w{3}\s+\w{3}\s+\d{1,2}\s+\d{4})\b"#, options: RX.opts
    )
    
    private let acRegex = try! NSRegularExpression(
        pattern: #"\bSPC\s+AC\s+(?<ac>\d{6})\b"#, options: RX.opts
    )
    
    private let prevDiscussionRegex = try! NSRegularExpression(
        pattern: #"\.PREV\s+DISCUSSION\.\.\.\s*(?<prev>.*?)(?=\s*\.\.\.\s*[^.][^.]*?\s*\.\.\.|$)"#, options: RX.opts
    )
    
    private let authorSigRegex = try! NSRegularExpression(
        pattern: #"\.\.[A-Za-z][A-Za-z.\- ]+\.\.\s*\d{2}/\d{2}/\d{4}"#, options: RX.opts
    )
    
    
    // MARK: - Core slicer
    
    private struct Section { let label: String; let body: String }
    
    private func sliceEllipsisSections(_ text: String) -> [Section] {
        let ns = text as NSString
        var out: [Section] = []
        for m in sectionSlicerRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let label = ns.substring(with: m.range(withName: "label")).trimmed()
            let body  = ns.substring(with: m.range(withName: "body")).trimmed()
            out.append(.init(label: label, body: body))
        }
        return out
    }
    
    // MARK: - Metadata extractors
    
    private func extractSummary(_ text: String) -> String? {
        summaryHeaderRegex.firstMatch(in: text)?.captured("summary", in: text)
    }
    
    private func extractValid(_ text: String) -> coDTO.Valid? {
        guard let m = validRegex.firstMatch(in: text),
              let start = m.captured("start", in: text),
              let end   = m.captured("end", in: text)
        else { return nil }
        return .init(startZ: start, endZ: end)
    }
    
    private func extractIssued(_ text: String) -> String? {
        let x = issuedExtractorRegex.firstMatch(in: text)?.captured("issued", in: text)?.trimmed()
        return x
    }
    
    private func extractAC(_ text: String) -> String? {
        acRegex.firstMatch(in: text)?.captured("ac", in: text)
    }
    
    // MARK: - Special blocks
    
    private func capturePrevDiscussion(_ text: String) -> String? {
        prevDiscussionRegex.firstMatch(in: text)?.captured("prev", in: text)?.trimmed()
    }
    
    //private func stripAuthorSignatures(_ text: String) -> String {
    //    authorSigRegex.stringByReplacingMatches(in: text, withTemplate: " ", range: <#NSRange#>)
    //}
    
    // MARK: - Utilities
    
    private func mapRiskLevel(_ s: String) -> coDTO.RiskLevel? {
        switch s {
        case "MARGINAL": return .marginal
        case "SLIGHT":   return .slight
        case "ENHANCED": return .enhanced
        case "MODERATE": return .moderate
        case "HIGH":     return .high
        default:         return nil
        }
    }
    
    private func normalizeHeader(_ s: String) -> String {
        // collapse whitespace and uppercase for routing; keep originals for display
        s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
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

private extension String {
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@available(*, deprecated, message: "Use the OutlookParser instead")
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
    
    private enum RX {
        static let opts: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    }
    
//    private let validRegex = try! NSRegularExpression(
//        pattern: #"\bvalid\s+(?<start>\d{6})\s*z?\s*-\s*(?<end>\d{6})\s*z?\b"#, options: RX.opts
//    )
    
    //    static func extractRiskLevel(from text: String) -> String? {
    //        let levels = ["MRGL", "SLGT", "ENH", "MDT", "HIGH"]
    //        return levels.first { text.contains($0) }
    //    }
}
