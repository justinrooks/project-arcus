//
//  StormSetupSummaryStatusCard.swift
//  SkyAware
//

import SwiftUI

struct StormSetupSummaryStatusCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let presentation: StormSetupSummaryStatusPresentation
    private let reduceMotionOverride: Bool?

    init(presentation: StormSetupSummaryStatusPresentation, reduceMotionOverride: Bool? = nil) {
        self.presentation = presentation
        self.reduceMotionOverride = reduceMotionOverride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Storm Setup", systemImage: "cloud.bolt.fill")
                .symbolVariant(.fill)
                .sectionLabel()

            HStack(alignment: .top, spacing: 10) {
                statusSymbol

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardBackground(
            cornerRadius: SkyAwareRadius.card,
            shadowOpacity: colorScheme == .dark ? 0.06 : 0.10,
            shadowRadius: colorScheme == .dark ? 6 : 8,
            shadowY: colorScheme == .dark ? 2 : 3
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storm Setup")
        .accessibilityValue(presentation.accessibilityValue)
    }

    @ViewBuilder
    private var statusSymbol: some View {
        if presentation.showsProgress, (reduceMotionOverride ?? reduceMotion) == false {
            ProgressView()
                .controlSize(.small)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
        } else {
            Image(systemName: presentation.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Storm Setup Status - Analyzing Light") {
    StormSetupSummaryStatusCard(presentation: .init(
        title: "Analyzing your storm setup",
        message: "Checking local ingredients and guidance for your area.",
        symbolName: "cloud.bolt.fill",
        showsProgress: true
    ))
    .padding()
    .background(.skyAwareBackground)
}

#Preview("Storm Setup Status - No Notable Dark") {
    StormSetupSummaryStatusCard(presentation: .init(
        title: "No notable storm setup",
        message: "Current guidance does not show a notable storm setup for your area.",
        symbolName: "checkmark.circle"
    ))
    .padding()
    .background(.skyAwareBackground)
    .preferredColorScheme(.dark)
}

#Preview("Storm Setup Status - Analysis Not Needed Accessibility") {
    StormSetupSummaryStatusCard(presentation: .init(
        title: "Analysis not needed",
        message: "Current conditions do not call for a Storm Setup analysis.",
        symbolName: "cloud.sun"
    ))
    .padding()
    .background(.skyAwareBackground)
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Storm Setup Status - Analyzing Reduce Motion") {
    StormSetupSummaryStatusCard(presentation: .init(
        title: "Analyzing your storm setup",
        message: "Checking local ingredients and guidance for your area.",
        symbolName: "cloud.bolt.fill",
        showsProgress: true
    ), reduceMotionOverride: true)
    .padding()
    .background(.skyAwareBackground)
}
