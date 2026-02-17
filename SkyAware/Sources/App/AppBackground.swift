//
//  AppBackground.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/7/25.
//

import SwiftUI

struct AppBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        ZStack {
            AtmosphericBackground(colorScheme: colorScheme)
            content
        }
            .ignoresSafeArea()
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }
}

private struct AtmosphericBackground: View {
    let colorScheme: ColorScheme

    private var topColor: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.16, blue: 0.24)
            : Color(red: 0.82, green: 0.90, blue: 0.98)
    }

    private var bottomColor: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.07, blue: 0.13)
            : Color(red: 0.68, green: 0.79, blue: 0.92)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [topColor, bottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(colorScheme == .dark ? 0.10 : 0.18))
                .blur(radius: 100)
                .frame(width: 360, height: 360)
                .offset(x: -130, y: -280)

            Circle()
                .fill(Color.skyAwareAccent.opacity(colorScheme == .dark ? 0.16 : 0.22))
                .blur(radius: 120)
                .frame(width: 300, height: 300)
                .offset(x: 170, y: 260)

            Rectangle()
                .fill(.black.opacity(colorScheme == .dark ? 0.22 : 0.08))
        }
    }
}
