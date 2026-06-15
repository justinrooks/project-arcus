//
//  RiskBadgeVisualStyle.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

enum RiskBadgeVisualStyle {
    enum Emphasis {
        case normal
        case subdued
    }

    static func iconForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.primary.opacity(0.92)
    }

    static func messageForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.98)
            : Color.primary.opacity(0.92)
    }

    static func summaryForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.84)
            : Color.primary.opacity(0.74)
    }

    static func badgeBackground(
        for base: Color,
        colorScheme: ColorScheme,
        emphasis: Emphasis = .normal
    ) -> LinearGradient {
        switch colorScheme {
        case .dark:
            let top = base.opacity(emphasis == .subdued ? 0.20 : 0.88)
            let bottom = base.darken(by: emphasis == .subdued ? 0.28 : 0.20)
            return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            let top = base.opacity(emphasis == .subdued ? 0.44 : 0.60)
            let bottom = base.opacity(emphasis == .subdued ? 0.78 : 0.94)
            return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func subduedFireBackground(for colorScheme: ColorScheme) -> LinearGradient {
        let base = Color.riskAllClear
        return badgeBackground(for: base, colorScheme: colorScheme, emphasis: .subdued)
    }
}
