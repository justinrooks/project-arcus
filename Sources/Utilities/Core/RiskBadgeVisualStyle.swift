//
//  RiskBadgeVisualStyle.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

enum RiskBadgeVisualStyle {
    static let iconForeground: Color = .primary
    static let messageForeground: Color = .primary

    static func summaryForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(1.85) : .secondary
    }

    static func subduedFireBackground(for colorScheme: ColorScheme) -> LinearGradient {
        let base = Color.riskAllClear
        let top = colorScheme == .dark
            ? base.opacity(0.18)
            : base.opacity(0.10)
        let bottom = colorScheme == .dark
            ? base.opacity(0.12)
            : base.opacity(0.15)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
