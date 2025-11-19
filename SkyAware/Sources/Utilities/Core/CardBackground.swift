//
//  CardBackground.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/13/25.
//

import SwiftUI

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = SkyAwareRadius.medium
    var shadowOpacity: Double = 0.12
    var shadowRadius: CGFloat = SkyAwareRadius.medium
    var shadowY: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.clear)
                            .shadow(
                                color: .black.opacity(shadowOpacity),
                                radius: shadowRadius,
                                x: 0,
                                y: shadowY
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
    }
}

//#Preview {
//    CardBackground()
//}
