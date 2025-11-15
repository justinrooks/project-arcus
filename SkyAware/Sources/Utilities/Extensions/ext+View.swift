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
    
    
    /// This modifier will allow you to display a "redacted" view or fuzzy view
    /// while content is loading as an example.
    /// - Parameter isActive: boolean evaluating to true/false. True redacts content, false displays it
    /// - Returns: a redaction configuration to apply to the view
    func placeholder(_ isActive: Bool) -> some View {
        self
            .redacted(reason: isActive ? .placeholder : [])
            .opacity(isActive ? 0.8 : 1)
            .animation(.snappy, value: isActive)
    }
    
    func cardBackground(
        cornerRadius: CGFloat = 16,
        shadowOpacity: Double = 0.22,
        shadowRadius: CGFloat = 16,
        shadowY: CGFloat = 6
    ) -> some View {
        self.modifier(
            CardBackground(
                cornerRadius: cornerRadius,
                shadowOpacity: shadowOpacity,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
        )
    }
    
    func cardRowBackground() -> some View {
        self
            .cardBackground()
        //                .padding(.vertical, 4)
        //                .padding(.horizontal, 8)
            .listRowInsets(EdgeInsets(top: 4, leading: -10, bottom: 4, trailing: -10))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    
    func mesoscaleCardChrome(for layout: DetailLayout) -> some View {
        let cornerRadius: CGFloat = 16
        let hPad: CGFloat = layout == .sheet ? 16 : 18
        let vPad: CGFloat = layout == .sheet ? 12 : 24
        let shadowOpacity: Double = layout == .full ? 0.10 : 0
        
        switch layout {
        case .sheet:
            return AnyView(
                self
                    .padding(.horizontal, hPad)
                    .padding(.vertical, vPad)
                    .background() {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.cardBackground)
                            .shadow(color: Color.black.opacity(shadowOpacity), radius: 12, x: 0, y: 5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
        case .full:
            return AnyView(
                self
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            )
        }
    }
}
