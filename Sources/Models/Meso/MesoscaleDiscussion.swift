//
//  MesoscaleDiscussion.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/11/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class MD {
    var id: UUID                // usually the GUID or derived from it
    @Attribute(.unique) var number: Int             // the MD number 1895
    var title: String           // e.g., "Day 1 Convective Outlook"
    var link: URL               // link to full outlook page
    var issued: Date            // Issued Date
    var validStart: Date        // Valid start
    var validEnd: Date          // Valid end
    var areasAffected: String   // locations affected by the meso
    var summary: String         // description / CDATA
    var concerning: String?     // e.g. "Severe potential... Watch unlikely"
    
    var watchProbability: String
    var threats: MDThreats?
    var coordinates: [Coordinate2D]
    
    var minLat: Double?
    var maxLat: Double?
    var minLon: Double?
    var maxLon: Double?
    
    var alertType: AlertType    // type of alert to conform to AlertItem

    convenience init? (from dto: MdDTO) {
        self.init(
            number: dto.number,
            title: dto.title,
            link: dto.link,
            issued: dto.issued,
            validStart: dto.validStart,
            validEnd: dto.validEnd,
            areasAffected: dto.areasAffected,
            summary: dto.summary,
            concerning: dto.concerning,
            watchProbability: String(dto.watchProbability),
            threats: dto.threats,
            coordinates: dto.coordinates,
            alertType: .mesoscale
        )
    }
    
    init(number: Int, title: String, link: URL, issued: Date, validStart: Date, validEnd: Date, areasAffected: String, summary: String, concerning: String? = nil, watchProbability: String, threats: MDThreats?, coordinates: [Coordinate2D], alertType: AlertType) {
        self.id = UUID()
        self.number = number
        self.title = title
        self.link = link
        self.issued = issued
        self.validStart = validStart
        self.validEnd = validEnd
        self.areasAffected = areasAffected
        self.summary = summary
        self.concerning = concerning
        self.watchProbability = watchProbability
        self.threats = threats
        self.coordinates = coordinates
        
        if !coordinates.isEmpty {
            let lats = coordinates.map(\.latitude)
            let lons = coordinates.map(\.longitude)
            
            self.minLat = lats.min()
            self.maxLat = lats.max()
            self.minLon = lons.min()
            self.maxLon = lons.max()
        } else {
            self.minLat = nil
            self.maxLat = nil
            self.minLon = nil
            self.maxLon = nil
        }
        
        self.alertType = alertType
    }
}

struct MDThreats: Sendable, Codable, Hashable {
    var peakWindMPH: Int?            // e.g. 60
    var hailRangeInches: Double? // e.g. 1.5...2.5
    var tornadoStrength: String?     // e.g. "Brief / weak", "EF1+ possible", or nil
}

struct GeoBBox: Sendable {
    let minLat: Double, maxLat: Double, minLon: Double, maxLon: Double
    
    func contains(_ p: CLLocationCoordinate2D) -> Bool {
        p.latitude >= minLat && p.latitude <= maxLat &&
        p.longitude >= minLon && p.longitude <= maxLon
    }
}

extension MD {
    nonisolated var ringCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.location }
    }
    
    nonisolated var bbox: GeoBBox? {
        guard let minLat, let maxLat, let minLon, let maxLon else { return nil }
        
        return GeoBBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
    
    func updateDerivedBBox() {
        if !coordinates.isEmpty {
            let lats = coordinates.map(\.latitude)
            let lons = coordinates.map(\.longitude)
            
            self.minLat = lats.min()
            self.maxLat = lats.max()
            self.minLon = lons.min()
            self.maxLon = lons.max()
        } else {
            self.minLat = nil
            self.maxLat = nil
            self.minLon = nil
            self.maxLon = nil
        }
    }
}


//enum WatchProbability: Hashable, Equatable, Sendable, Codable {
//    case percent(Int)   // 0...100
//    case unlikely
//}

//struct MesoscaleDiscussion: Identifiable, Hashable, Equatable, AlertItem {
//    let id: UUID                // usually the GUID or derived from it
//    let number: Int             // the MD number 1895
//    let title: String           // e.g., "Day 1 Convective Outlook"
//    let link: URL               // link to full outlook page
//    let issued: Date            // Issued Date
//    let validStart: Date        // Valid start
//    let validEnd: Date          // Valid end
//    let areasAffected: String   // locations affected by the meso
//    let summary: String         // description / CDATA
//    let concerning: String?     // e.g. "Severe potential... Watch unlikely"
//    let watchProbability: WatchProbability
//    let threats: MDThreats
//    let coordinates: [CLLocationCoordinate2D]
//    let alertType: AlertType    // type of alert to conform to AlertItem
//}
//
//extension MesoscaleDiscussion {
//        // Equality: base on stable identifiers/fields; ignore polygon coordinates to avoid float noise
//        static func == (lhs: MesoscaleDiscussion, rhs: MesoscaleDiscussion) -> Bool {
//            return lhs.id == rhs.id
//                && lhs.number == rhs.number
//                && lhs.title == rhs.title
//                && lhs.link == rhs.link
//                && lhs.issued == rhs.issued
//                && lhs.validStart == rhs.validStart
//                && lhs.validEnd == rhs.validEnd
//                && lhs.areasAffected == rhs.areasAffected
//                && lhs.summary == rhs.summary
//                && lhs.concerning == rhs.concerning
//                && lhs.watchProbability == rhs.watchProbability
//                && lhs.threats == rhs.threats
//                // polygon intentionally excluded (CLLocationCoordinate2D is not Hashable and can suffer precision drift)
//        }
//
//        // Hashing: hash the same stable fields; exclude polygon
//        func hash(into hasher: inout Hasher) {
//            hasher.combine(id)
//            hasher.combine(number)
//            hasher.combine(title)
//            hasher.combine(link)
//            hasher.combine(issued)
//            hasher.combine(validStart)
//            hasher.combine(validEnd)
//            hasher.combine(areasAffected)
//            hasher.combine(summary)
//            hasher.combine(concerning)
//            hasher.combine(watchProbability)
//            hasher.combine(threats)
//            // polygon intentionally excluded
//        }
//        
//    // MARK: - Parsing (private)
//
//    // Utility: first capture helper
//    private static func first(_ text: String, _ re: Regex<AnyRegexOutput>) -> String? {
//        guard let m = text.firstMatch(of: re), let r = m.output[1].range else { return nil }
//        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
//    }
//
//    // Parse MD number from link (md####.html)
//    private static func parseMDNumber(from url: URL) -> Int? {
//        let s = url.absoluteString
//        guard
//            let r = s.range(of: #"md(\d{3,4})\.html"#, options: .regularExpression),
//            let m = try? NSRegularExpression(pattern: #"md(\d{3,4})\.html"#)
//                .firstMatch(in: s, range: NSRange(r, in: s)),
//            m.numberOfRanges == 2,
//            let gr = Range(m.range(at: 1), in: s)
//        else { return nil }
//        return Int(s[gr])
//    }
//
//    // Parse Valid range (Z times) relative to issued date (UTC). Handles crossing 00Z boundary.
//    private static func parseValid(_ text: String, issued: Date) -> (Date, Date)? {
//        let reValid = try! Regex(#"(?im)^\s*Valid\s+(\d{2})(\d{2})Z\s*-\s*(\d{2})(\d{2})Z\s*$"#)
//        guard let m = text.firstMatch(of: reValid) else { return nil }
//        let sH = Int(String(text[m.output[1].range!]))!
//        let sM = Int(String(text[m.output[2].range!]))!
//        let eH = Int(String(text[m.output[3].range!]))!
//        let eM = Int(String(text[m.output[4].range!]))!
//
//        var cal = Calendar(identifier: .gregorian)
//        cal.timeZone = TimeZone(secondsFromGMT: 0)!
//
//        // Build start on issued day in UTC
//        let comps = cal.dateComponents(in: cal.timeZone, from: issued)
//        let start = cal.date(from: DateComponents(calendar: cal,
//                                                 timeZone: cal.timeZone,
//                                                 year: comps.year,
//                                                 month: comps.month,
//                                                 day: comps.day,
//                                                 hour: sH, minute: sM))!
//        var end   = cal.date(from: DateComponents(calendar: cal,
//                                                 timeZone: cal.timeZone,
//                                                 year: comps.year,
//                                                 month: comps.month,
//                                                 day: comps.day,
//                                                 hour: eH, minute: eM))!
//        // If end before start, roll to next day
//        if end < start { end = cal.date(byAdding: .day, value: 1, to: end)! }
//        return (start, end)
//    }
//
//    // Parse watch probability + concerning line
//    private static func parseWatchFields(_ text: String) -> (WatchProbability, String?) {
//        var probability: WatchProbability? = nil
//        var concerningText: String? = nil
//
//        // --- Probability of Watch Issuance ---
//        if let pwoiMatch = text.firstMatch(of: try! Regex(#"(?im)Probability\ of\ Watch\ Issuance\.\.\.\s*([0-9]{1,3})\s*percent\b"#)) {
//            if let range = pwoiMatch.output[1].range,
//               let pct = Int(text[range]) {
//                probability = .percent(min(max(pct, 0), 100))
//            }
//        }
//
//        // --- Concerning line ---
//        if let concerningMatch = text.firstMatch(of: try! Regex(#"(?im)Concerning\.\.\.\s*(.+)$"#)) {
//            if let range = concerningMatch.output[1].range {
//                let raw = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
//                // Clean up trailing spaces or extra dots
//                concerningText = raw.replacingOccurrences(of: #"\s+\.\.\."#, with: "", options: .regularExpression)
//            }
//        }
//
//        // --- Active watch form (Tornado/Severe Thunderstorm Watch #s) ---
//        if let watchMatch = text.firstMatch(of: try! Regex(#"(?im)Concerning\.\.\.\s*(Tornado|Severe\ Thunderstorm)\s+Watch(?:es)?\s+([^\n]+)"#)) {
//            if let typeRange = watchMatch.output[1].range,
//               let numRange = watchMatch.output[2].range {
//                let type = String(text[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
//                let tail = String(text[numRange]).trimmingCharacters(in: .whitespacesAndNewlines)
//                let ids = tail.matches(of: try! Regex(#"\d+"#)).compactMap { Int(String(tail[$0.range])) }
//                let line = ids.isEmpty ? "\(type) Watch \(tail)" : "\(type) Watch \(ids.map(String.init).joined(separator: ", "))"
//                concerningText = line
//                if probability == nil {
//                    probability = .unlikely
//                }
//            }
//        }
//
//        // --- Fallback if no probability found ---
//        if probability == nil {
//            if text.range(of: #"watch\s+unlikely"#, options: [.regularExpression, .caseInsensitive]) != nil {
//                probability = .unlikely
//            }
//        }
//
//        return (probability ?? .unlikely, concerningText)
//    }
//
//    // Parse the areas affected
//    private static func parseAreas(_ text: String) -> String {
//        let reAreas   = try! Regex(#"(?is)Areas affected\.\.\.\s*(.*?)\s*(?=Concerning\.\.\.)"#)
//        return first(text, reAreas) ?? ""
//    }
//    
//    // Parse the summary and discussion
//    private static func parseSummary(_ text: String) -> String {
//        let reSummary = try! Regex(#"(?is)SUMMARY\.\.\.\s*(.*?)\s*(?=DISCUSSION\.\.\.)"#)
//        return first(text, reSummary) ?? ""
//    }
//    
//    // Parse wind mph: choose the upper bound when a range is provided
//    private static func parseWindMPH(_ text: String) -> Int? {
//        let reWind = try! Regex(#"(?im)^\s*MOST PROBABLE PEAK WIND GUST\.\.\.\s*([0-9]{2,3})(?:\s*-\s*([0-9]{2,3}))?\s*(?:MPH|KT)\b.*$"#)
//        guard let m = text.firstMatch(of: reWind) else { return nil }
//        if let hiR = m.output[2].range { return Int(String(text[hiR])) }
//        if let loR = m.output[1].range { return Int(String(text[loR])) }
//        return nil
//    }
//
//    // Parse hail inches as Double? (modified)
//    private static func parseHailRange(_ text: String) -> Double? {
//        let reHail = try! Regex(#"(?im)^\s*MOST PROBABLE PEAK HAIL SIZE\.\.\.\s*(?:UP TO\s*)?([0-9]+(?:\.[0-9]+)?)(?:\s*-\s*([0-9]+(?:\.[0-9]+)?))?\s*IN\b.*$"#)
//        guard let m = text.firstMatch(of: reHail) else { return nil }
//        let low = Double(String(text[m.output[1].range!]))!
//        if let hiR = m.output[2].range {
//            let high = Double(String(text[hiR]))!
//            // When a range is provided, use the upper bound as the representative value
//            return max(low, high)
//        } else {
//            // Single value or "UP TO" value: use that value directly
//            return low
//        }
//    }
//
//    // Tornado strength as free text (e.g., "UP TO 95 MPH", "EF1-2 possible")
//    private static func parseTornadoStrength(_ text: String) -> String? {
//        let reTor = try! Regex(#"(?im)^\s*MOST PROBABLE PEAK TORNADO (?:INTENSITY|STRENGTH)\.\.\.\s*([^\n]+)$"#)
//        return first(text, reTor)
//    }
//
//    static func from(rssItem: Item) -> MesoscaleDiscussion? {
//        guard
//            let title = rssItem.title,
//            let linkString = rssItem.link,
//            let link = URL(string: linkString),
//            let pubDateString = rssItem.pubDate,
//            let rawText = rssItem.description, // SPC MD free text lives here in your feed
//            let issued = DateFormatter.rfc822.date(from: pubDateString)
//        else { return nil }
//
//        let mdNumber = parseMDNumber(from: link) ?? {
//            // Fallback: try to read from title if present
//            if let r = title.range(of: #"\b(\d{3,4})\b"#, options: .regularExpression) { return Int(title[r]) } else { return nil }
//        }() ?? -1
//
//        // Areas / Summary (block captures)
//        let areasAffected = parseAreas(rawText)
//        let summaryParsed = parseSummary(rawText)
//
//        // Valid range (UTC), fallback to issued+2h if missing
//        let validPair = parseValid(rawText, issued: issued)
//        let validStart = validPair?.0 ?? issued
//        let validEnd   = validPair?.1 ?? Calendar.current.date(byAdding: .hour, value: 2, to: issued)!
//
//        // Watch probability + concerning
//        let (watchProb, concerningLine) = parseWatchFields(rawText)
//
//        // Threats
//        let windMPH  = parseWindMPH(rawText)
//        let hailRng  = parseHailRange(rawText)
//        let torText  = parseTornadoStrength(rawText)
//
//        let threats = MDThreats(
//            peakWindMPH: windMPH,
//            hailRangeInches: hailRng,
//            tornadoStrength: torText
//        )
//        
//        return MesoscaleDiscussion(
//            id: UUID(),
//            number: mdNumber,
//            title: title,
//            link: link,
//            issued: issued,
//            validStart: validStart,
//            validEnd: validEnd,
//            areasAffected: areasAffected,
//            summary: summaryParsed.isEmpty ? rawText : summaryParsed,
//            concerning: concerningLine,
//            watchProbability: watchProb,
//            threats: threats,
//            coordinates: MesoGeometry.coordinates(from: rawText) ?? [],
//            alertType: .mesoscale
//        )
//    }
//}

