//
//  AppBackground.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/7/25.
//

import SwiftUI

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.skyAwareBackground)
            .ignoresSafeArea()
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }
}
