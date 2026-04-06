//
//  WatchParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/23/25.
//

import Foundation

enum WatchParser {
    static func parseWatchNumber(from url: URL) -> Int? {
        let s = url.absoluteString
        guard
            let r = s.range(of: #"ww(\d{3,4})\.html"#, options: .regularExpression),
            let m = try? NSRegularExpression(pattern: #"ww(\d{3,4})\.html"#)
                .firstMatch(in: s, range: NSRange(r, in: s)),
            m.numberOfRanges == 2,
            let gr = Range(m.range(at: 1), in: s)
        else { return nil }
        return Int(s[gr])
    }
    
    static func parseValid(_ text: String, issued: Date) -> (Date, Date)? {
        let reValid = try! Regex(#"(?im).*?(\d{2})(\d{2})(\d{2})Z\s*-\s*(\d{2})(\d{2})(\d{2})Z.*$"#)
        
        guard let m = text.firstMatch(of: reValid) else { return nil }
        //let sD = Int(String(text[m.output[1].range!]))!
        let sH = Int(String(text[m.output[2].range!]))!
        let sM = Int(String(text[m.output[3].range!]))!
        //let eD = Int(String(text[m.output[4].range!]))!
        let eH = Int(String(text[m.output[5].range!]))!
        let eM = Int(String(text[m.output[6].range!]))!

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
}
