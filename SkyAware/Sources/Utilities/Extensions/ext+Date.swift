//
//  ext+Date.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation

extension Date {
//    func toRFC1123String() -> String {
//        let formatter = DateFormatter()
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        formatter.timeZone = TimeZone(secondsFromGMT: 0)
//        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
//        return formatter.string(from: self)
//    }

    /// Conveniently wraps a date formatter with accessible date and time styles that are configurable
    /// - Parameters:
    ///   - dateStyle: defaults to medium (Nov 14, 2025)
    ///   - timeStyle: defaults to short (9:10 AM)
    /// - Returns: returns a date as a string with the configured format
    func shorten(
        withDateStyle dateStyle: DateFormatter.Style = .medium,
        withTimeStyle timeStyle: DateFormatter.Style = .short
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
    
    
    /// Computes a date and time relative to the provided date
    /// - Parameters:
    ///   - date: defaults to now, or can be specified
    ///   - style: defaults to abbreviated, or can be specified
    /// - Returns: a string like 4h ago
    func relativeDate(to date: Date = .now, with style: RelativeDateTimeFormatter.UnitsStyle = .abbreviated) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = style
        return formatter.localizedString(for: self, relativeTo: date)
    }
    
//    func shortRelativeDescription(to referenceDate: Date = .now) -> String {
//            let seconds = Int(referenceDate.timeIntervalSince(self))
//            switch seconds {
//            case ..<60:
//                return "\(seconds)s"
//            case ..<3600:
//                return "\(seconds / 60)m"
//            case ..<86_400:
//                return "\(seconds / 3600)h"
//            default:
//                return "\(seconds / 86_400)d"
//            }
//        }
}
