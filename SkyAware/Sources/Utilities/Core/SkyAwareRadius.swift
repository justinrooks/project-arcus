//
//  SkyAwareRadius.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/18/25.
//

import CoreGraphics

enum SkyAwareRadius {
    // MARK: Shared Surface Scale (outer -> inner)
    static let hero: CGFloat = 26
    static let card: CGFloat = 24
    static let section: CGFloat = 22
    static let content: CGFloat = 20
    static let row: CGFloat = 18
    static let tile: CGFloat = 16
    static let chip: CGFloat = 12
    static let chipCompact: CGFloat = 10
    static let iconChip: CGFloat = 14
    static let circularButton: CGFloat = 17

    // MARK: Compatibility aliases (keep existing callers stable)
    static let large: CGFloat = 30
    static let medium: CGFloat = section
    static let small: CGFloat = tile
    static let capsule: CGFloat = 999

    static func inset(_ radius: CGFloat, by amount: CGFloat) -> CGFloat {
        max(0, radius - amount)
    }
}
