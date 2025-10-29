//
//  ext+String.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation

extension String {
    /// Parses SPC/NWS date strings like "202508052000" (UTC) into a Date
    func asUTCDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: self)
    }
    
    /// Parses an RFC1123 string into a Date
    func fromRFC1123String() -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        return formatter.date(from: self)
    }
}
