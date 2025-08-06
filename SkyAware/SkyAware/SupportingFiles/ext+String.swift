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
}
