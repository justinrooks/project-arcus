//
//  ext+Date.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation

private enum DateFormattingCache {
    static func formatter(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> DateFormatter {
        let key = "SkyAware.DateFormatter.\(dateStyle.rawValue).\(timeStyle.rawValue)"
        let threadDictionary = Thread.current.threadDictionary
        if let cached = threadDictionary[key] as? DateFormatter {
            return cached
        }

        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        threadDictionary[key] = formatter
        return formatter
    }

    static func relativeFormatter(style: RelativeDateTimeFormatter.UnitsStyle) -> RelativeDateTimeFormatter {
        let key = "SkyAware.RelativeDateTimeFormatter.\(style.cacheKey)"
        let threadDictionary = Thread.current.threadDictionary
        if let cached = threadDictionary[key] as? RelativeDateTimeFormatter {
            return cached
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = style
        threadDictionary[key] = formatter
        return formatter
    }
}

private extension RelativeDateTimeFormatter.UnitsStyle {
    var cacheKey: String {
        switch self {
        case .full:
            return "full"
        case .short:
            return "short"
        case .abbreviated:
            return "abbreviated"
        case .spellOut:
            return "spellOut"
        @unknown default:
            return "unknown"
        }
    }
}

extension Date {
    /// Conveniently wraps a date formatter with accessible date and time styles that are configurable
    /// - Parameters:
    ///   - dateStyle: defaults to medium (Nov 14, 2025)
    ///   - timeStyle: defaults to short (9:10 AM)
    /// - Returns: returns a date as a string with the configured format
    func shorten(
        withDateStyle dateStyle: DateFormatter.Style = .medium,
        withTimeStyle timeStyle: DateFormatter.Style = .short
    ) -> String {
        let formatter = DateFormattingCache.formatter(dateStyle: dateStyle, timeStyle: timeStyle)
        return formatter.string(from: self)
    }

    /// Computes a date and time relative to the provided date
    /// - Parameters:
    ///   - date: defaults to now, or can be specified
    ///   - style: defaults to abbreviated, or can be specified
    /// - Returns: a string like 4h ago
    func relativeDate(to date: Date = .now, with style: RelativeDateTimeFormatter.UnitsStyle = .abbreviated) -> String {
        let formatter = DateFormattingCache.relativeFormatter(style: style)
        return formatter.localizedString(for: self, relativeTo: date)
    }
}
