//
//  ext+View.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension View {
    func badgeStyle(background: LinearGradient) -> some View {
        self
            .frame(minWidth: 100, idealWidth: 135, maxWidth: 135,
                   minHeight: 100, idealHeight: 135, maxHeight: 135)
            .aspectRatio(1, contentMode: .fit)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(background)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            )
    }
}
