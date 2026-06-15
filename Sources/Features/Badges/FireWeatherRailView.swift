//
//  FireWeatherRailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/17/26.
//

import SwiftUI

struct FireWeatherRailView: View {
    @Environment(\.colorScheme) var colorScheme
    let level: FireRiskLevel?
    var isOffline: Bool = false
    var showsResolvingPlaceholder: Bool = false

    var body: some View {
        Group {
            switch presentationState {
            case .resolving:
                resolvingContent
            case .current, .stale:
                if let level {
                    resolvedContent(level: level)
                } else {
                    unavailableContent
                }
            case .unavailable, .confirmedEmpty:
                unavailableContent
            }
        }
    }

    private var presentationState: SummaryContentPresentationState {
        SummaryContentPresentationState.from(
            isOffline: isOffline,
            hasContent: level != nil,
            isResolving: showsResolvingPlaceholder
        )
    }

    private var resolvingBackground: LinearGradient {
        let colors: [Color] = colorScheme == .dark
        ? [Color(red: 0.17, green: 0.22, blue: 0.30).opacity(0.93),
           Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.93)]
        : [Color(red: 0.87, green: 0.91, blue: 0.96),
           Color(red: 0.82, green: 0.87, blue: 0.93)]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private func resolvedContent(level: FireRiskLevel) -> some View {
        let presentation = level.supportingPresentation()

        HStack(spacing: 12) {
            Image(systemName: level.symbol)
                .formatBadgeImage(size: 35 * presentation.iconScale, colorScheme: colorScheme)
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .formatMessageText(for: colorScheme)
                Text(presentation.detail)
                    .formatSummaryText(for: colorScheme)
            }
        }
        .railStyle(
            background: presentation.isSubdued
                ? RiskBadgeVisualStyle.subduedFireBackground(for: colorScheme)
                : level.iconColor(for: colorScheme),
            minHeight: presentation.isSubdued ? 76 : 84,
            shadowOpacity: presentation.isSubdued ? 0.10 : 0.18,
            shadowRadius: presentation.isSubdued ? 6 : 8,
            shadowY: presentation.isSubdued ? 3 : 4
        )
        .overlay(alignment: .topTrailing) {
            if isOffline {
                SummaryAvailabilityBadge(state: .stale)
                    .padding(.trailing, 12)
                    .padding(.top, 8)
            }
        }
    }

    private var resolvingContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame")
                .formatBadgeImage(colorScheme: colorScheme)
            VStack(alignment: .leading, spacing: 3) {
                Text("Fire Risk")
                    .formatMessageText(for: colorScheme)
                Text("Getting fire risk…")
                    .formatSummaryText(for: colorScheme)
            }
        }
        .railStyle(background: resolvingBackground)
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unavailable", systemImage: "exclamationmark.circle")
                .sectionLabel()
            Text("No saved fire risk data is available offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding([.leading, .trailing], 15)
        .cardBackground(cornerRadius: SkyAwareRadius.large, shadowOpacity: 0.18, shadowRadius: 8, shadowY: 4)
    }
}

#Preview {
    VStack {
        FireWeatherRailView(level: .clear)
        FireWeatherRailView(level: .clear, isOffline: true)
        FireWeatherRailView(level: .elevated)
        FireWeatherRailView(level: .elevated, isOffline: true)
    }
}

#Preview("Fire Weather Rail Dark") {
    VStack {
        FireWeatherRailView(level: .clear)
        FireWeatherRailView(level: .clear, isOffline: true)
        FireWeatherRailView(level: .elevated)
        FireWeatherRailView(level: .elevated, isOffline: true)
    }
    .preferredColorScheme(.dark)
}

//    private var fireRiskState: FireRiskLevel {
//        let watchTitles = watches.map { $0.title.localizedLowercase }
//
//        if watchTitles.contains(where: { $0.contains("red flag warning") || $0.contains("extreme fire") }) {
//            return .critical
//        }
//
//        if watchTitles.contains(where: { $0.contains("fire weather watch") || $0.contains("red flag") }) {
//            return .elevated
//        }
//
//        return .clear
//    }
