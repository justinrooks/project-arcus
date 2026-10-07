import SwiftUI

enum TodaySurfaceStyle {
    static func canvas(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.skyAwareBackground
            : Color(red: 0xF5 / 255, green: 0xF6 / 255, blue: 0xF7 / 255)
    }

    static func content(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground)
            : Color(red: 0xFC / 255, green: 0xFC / 255, blue: 0xFD / 255)
    }

    static func sectionHeadingForeground(
        for colorScheme: ColorScheme,
        contrast: ColorSchemeContrast
    ) -> Color {
        guard colorScheme == .light else { return .primary }
        return contrast == .increased ? .primary : .primary.opacity(0.78)
    }

    static func supportingTextForeground(
        for colorScheme: ColorScheme,
        contrast: ColorSchemeContrast
    ) -> Color {
        guard colorScheme == .light else { return .secondary }
        return contrast == .increased ? .primary : .primary.opacity(0.68)
    }
}

private struct TodayCardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let cornerRadius: CGFloat
    let darkShadowOpacity: Double
    let darkShadowRadius: CGFloat
    let darkShadowY: CGFloat

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.cardBackground(
                cornerRadius: cornerRadius,
                shadowOpacity: darkShadowOpacity,
                shadowRadius: darkShadowRadius,
                shadowY: darkShadowY
            )
        } else {
            content.background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(TodaySurfaceStyle.content(for: colorScheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                Color.primary.opacity(colorSchemeContrast == .increased ? 0.14 : 0.06),
                                lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                            )
                    }
            }
        }
    }
}

private struct TodaySectionLabel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .font(.headline.weight(.semibold))
            .foregroundStyle(
                TodaySurfaceStyle.sectionHeadingForeground(for: colorScheme, contrast: colorSchemeContrast)
            )
    }
}

private struct TodaySupportingText: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content.foregroundStyle(
            TodaySurfaceStyle.supportingTextForeground(for: colorScheme, contrast: colorSchemeContrast)
        )
    }
}

extension View {
    func todayCardBackground(
        cornerRadius: CGFloat = SkyAwareRadius.card,
        darkShadowOpacity: Double = 0.04,
        darkShadowRadius: CGFloat = 4,
        darkShadowY: CGFloat = 1
    ) -> some View {
        modifier(
            TodayCardBackground(
                cornerRadius: cornerRadius,
                darkShadowOpacity: darkShadowOpacity,
                darkShadowRadius: darkShadowRadius,
                darkShadowY: darkShadowY
            )
        )
    }

    func todaySectionLabel() -> some View {
        modifier(TodaySectionLabel())
    }

    func todaySupportingText() -> some View {
        modifier(TodaySupportingText())
    }
}
