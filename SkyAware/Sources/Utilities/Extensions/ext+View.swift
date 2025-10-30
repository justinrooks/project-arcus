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
            .frame(minWidth: 130, idealWidth: 145, maxWidth: 145,
                   minHeight: 130, idealHeight: 145, maxHeight: 145)
            .aspectRatio(1, contentMode: .fit)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(background)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            )
    }
}
