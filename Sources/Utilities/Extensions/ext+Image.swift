//
//  ext+Image.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension Image {
    func formatBadgeImage(size: CGFloat = 35, colorScheme: ColorScheme? = nil) -> some View {
        self.resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .font(.largeTitle)
            .foregroundColor(
                colorScheme.map { RiskBadgeVisualStyle.iconForeground(for: $0) } ?? .primary
            )
    }
}
