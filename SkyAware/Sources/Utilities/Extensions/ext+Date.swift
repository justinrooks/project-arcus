//
//  ext+Date.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation

extension Date {
    func toRFC1123String() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
        return formatter.string(from: self)
    }
    
    /// Formats to a short time style and ommits the date entirely
    /// - Returns: string of the date formatted with short time only
    func toShortTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    // 📆 Helper for formatting the date
    func toShortDateAndTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func relativeDate() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func shortRelativeDescription(to referenceDate: Date = .now) -> String {
            let seconds = Int(referenceDate.timeIntervalSince(self))
            switch seconds {
            case ..<60:
                return "\(seconds)s"
            case ..<3600:
                return "\(seconds / 60)m"
            case ..<86_400:
                return "\(seconds / 3600)h"
            default:
                return "\(seconds / 86_400)d"
            }
        }
}
