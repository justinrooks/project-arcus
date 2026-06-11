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
}
