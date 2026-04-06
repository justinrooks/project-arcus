//
//  ext+Text.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension Text {
    func formatSummaryText(for colorScheme: ColorScheme) -> some View {
        self.font(.caption)
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(1.85) : .secondary)
    }
    
    func formatMessageText() -> some View {
        self.font(.headline)
            .foregroundColor(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
    
    // Meso detail
    func labelStyle() -> some View { self.font(.caption.smallCaps()).foregroundStyle(.secondary) }
    func valueStyle(multiline: Bool = false) -> some View {
        self.font(.footnote.monospaced())
            .foregroundStyle(.primary)
            .lineLimit(multiline ? 3 : 1)
    }
}
