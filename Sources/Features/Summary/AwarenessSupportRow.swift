//
//  AwarenessSupportRow.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct AwarenessSupportRow: View {
    @ScaledMetric(relativeTo: .caption2) private var compactIntensityDetailSize = 10.0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let detail: String
    let symbolName: String
    let background: LinearGradient
    var category: String? = nil
    var accent: Color? = nil
    var categorySymbolName: String? = nil
    var intensity: SevereIntensityPresentation? = nil
    var isQuiet: Bool = false
    var presentationMode: SupportingRiskRowPresentationMode = .normal
    var showsChevron: Bool = false
    var semanticTint: Color? = nil

    private var outlineColor: Color {
        if colorScheme == .dark {
            return .white.opacity(strokeOpacity)
        }
        guard category != nil else { return .clear }
        return .primary.opacity(colorSchemeContrast == .increased ? 0.14 : 0.06)
    }

    private var outlineWidth: CGFloat {
        if colorScheme == .dark { return 0.8 }
        guard category != nil else { return 0 }
        return colorSchemeContrast == .increased ? 1 : 0.5
    }

    var body: some View {
        let rowMetrics = metrics
        content(rowMetrics)
        .padding(.horizontal, rowMetrics.horizontalPadding)
        .padding(.vertical, category == nil ? rowMetrics.verticalPadding : 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .fill(category == nil ? Color.clear : TodaySurfaceStyle.content(for: colorScheme))
                .overlay {
                    if category == nil {
                        RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                            .fill(background)
                    }
                }
                .overlay {
                    if let semanticTint, category != nil {
                        AwarenessSemanticTint(accent: semanticTint, isQuiet: isQuiet)
                    }
                }
                .overlay(alignment: .leading) {
                    if let intensity, category == nil {
                        SevereIntensityTexture(level: intensity.level)
                            .frame(width: 44)
                            .clipped()
                    }
                }
                .overlay(alignment: .leading) {
                    if let accent, category != nil {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(accent)
                                .frame(width: 5, height: max(0, proxy.size.height - 24))
                                .position(x: 14.5, y: proxy.size.height / 2)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .strokeBorder(outlineColor, lineWidth: outlineWidth)
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? (isQuiet ? 0.06 : 0.10) : 0),
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .opacity(rowOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category ?? title)
        .accessibilityValue(intensity.map {
            [category == nil ? nil : title, detail, $0.title, $0.detail]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        } ?? (category == nil ? detail : [title, detail].filter { !$0.isEmpty }.joined(separator: ". ")))
    }

    @ViewBuilder
    private func content(_ rowMetrics: Metrics) -> some View {
        if let category, accent != nil {
            Group {
                if usesAccessibilityLayout {
                    VStack(alignment: .leading, spacing: 3) {
                        categoryDetails(category)
                        if let intensity { intensityDetails(intensity) }
                    }
                    .padding(.leading, 18)
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        categoryDetails(category)
                            .frame(width: intensity == nil ? nil : 165, alignment: .leading)
                        if let intensity {
                            intensityDetails(intensity)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1)
                        }
                    }
                    .padding(.leading, 18)
                    .frame(minHeight: 78, alignment: .leading)
                }
            }
        } else {
            legacyContent(rowMetrics)
        }
    }

    private var categoryChevron: some View {
        AwarenessNavigationChevron(accent: accent ?? .secondary)
    }

    private func categoryDetails(_ category: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 7) {
                Image(systemName: categorySymbolName ?? symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent ?? .secondary)
                    .frame(width: 17)
                    .accessibilityHidden(true)
                Text(category)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                if showsChevron, intensity == nil || usesAccessibilityLayout {
                    Spacer(minLength: 0)
                    categoryChevron
                }
            }
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.caption)
                .todaySupportingText()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func intensityDetails(_ intensity: SevereIntensityPresentation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 5) {
                SevereIntensityTexture(level: intensity.level)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text(intensity.title)
                    .font(.caption2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if showsChevron, category != nil, !usesAccessibilityLayout {
                    Spacer(minLength: 0)
                    categoryChevron
                }
            }

            Text(intensity.detail)
                .font(.system(size: compactIntensityDetailSize, weight: .regular, design: .default))
                .todaySupportingText()
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(-2)
        }
    }

    private func legacyContent(_ rowMetrics: Metrics) -> some View {
            HStack(spacing: rowMetrics.horizontalSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: rowMetrics.iconSize, weight: .semibold))
                .foregroundColor(RiskBadgeVisualStyle.iconForeground(for: colorScheme))
                .frame(width: rowMetrics.iconSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: rowMetrics.verticalSpacing) {
                Text(title)
                    .font(rowMetrics.titleFont)
                    .foregroundColor(RiskBadgeVisualStyle.messageForeground(for: colorScheme))
                    .lineLimit(usesAccessibilityLayout ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if !detail.isEmpty {
                    Text(detail)
                        .font(rowMetrics.detailFont)
                        .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                        .lineLimit(usesAccessibilityLayout ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let intensity {
                    Text(intensity.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    Text(intensity.detail)
                        .font(.footnote)
                        .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var metrics: Metrics {
        switch presentationMode {
        case .normal:
            return Metrics(
                iconSize: 26,
                horizontalSpacing: 10,
                verticalSpacing: 2,
                horizontalPadding: 12,
                verticalPadding: 10,
                titleFont: .subheadline.weight(.semibold),
                detailFont: .footnote
            )
        case .subdued:
            return Metrics(
                iconSize: 22,
                horizontalSpacing: 10,
                verticalSpacing: 2,
                horizontalPadding: 12,
                verticalPadding: 9,
                titleFont: .subheadline.weight(.semibold),
                detailFont: .footnote
            )
        case .supplemental:
            return Metrics(
                iconSize: 24,
                horizontalSpacing: 10,
                verticalSpacing: 2,
                horizontalPadding: 12,
                verticalPadding: 10,
                titleFont: .subheadline.weight(.semibold),
                detailFont: .footnote
            )
        }
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private struct Metrics {
        let iconSize: CGFloat
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let titleFont: Font
        let detailFont: Font
    }

    private var rowOpacity: Double {
        switch presentationMode {
        case .normal:
            return isQuiet ? 0.96 : 1
        case .subdued:
            return 0.92
        case .supplemental:
            return 1
        }
    }

    private var strokeOpacity: Double {
        switch presentationMode {
        case .normal:
            return isQuiet ? 0.08 : 0.12
        case .subdued:
            return 0.06
        case .supplemental:
            return 0.12
        }
    }

    private var shadowRadius: CGFloat {
        switch presentationMode {
        case .normal:
            return 5
        case .subdued:
            return 3
        case .supplemental:
            return 5
        }
    }

    private var shadowY: CGFloat {
        switch presentationMode {
        case .normal:
            return 2
        case .subdued:
            return 1
        case .supplemental:
            return 2
        }
    }
}
