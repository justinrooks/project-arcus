//
//  Relative.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

enum Relative {
    static let rtf: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    static func fromNow(_ date: Date) -> String {
        rtf.localizedString(for: date, relativeTo: .now)
    }
}
