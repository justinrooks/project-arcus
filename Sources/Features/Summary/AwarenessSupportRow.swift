//
//  AwarenessSupportRow.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct AwarenessSupportRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let detail: String
    let symbolName: String
    let background: LinearGradient
    var isQuiet: Bool = false
    var presentationMode: SupportingRiskRowPresentationMode = .normal
    var showsChevron: Bool = false

    var body: some View {
        let rowMetrics = metrics

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
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(rowMetrics.detailFont)
                    .foregroundStyle(RiskBadgeVisualStyle.summaryForeground(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, rowMetrics.horizontalPadding)
        .padding(.vertical, rowMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .fill(background)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous)
                .strokeBorder(.white.opacity(strokeOpacity), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(isQuiet ? 0.06 : 0.10),
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .opacity(rowOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
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
