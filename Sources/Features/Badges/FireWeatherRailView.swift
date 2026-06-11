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
        let riskLabel = level.status == "Clear" ? "No" : level.status

        HStack(spacing: 12) {
            Image(systemName: level.symbol)
                .formatBadgeImage()
            VStack(alignment: .leading, spacing: 3) {
                Text("\(riskLabel) Fire Risk")
                    .formatMessageText()
                Text(level.message)
                    .formatSummaryText(for: colorScheme)
            }
        }
        .railStyle(background: level.iconColor(for: colorScheme))
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
                .formatBadgeImage()
            VStack(alignment: .leading, spacing: 3) {
                Text("Fire Risk")
                    .formatMessageText()
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
        .cardBackground(cornerRadius: SkyAwareRadius.large, shadowOpacity: 0.18, shadowRadius: 8, shadowY: 4, allowsGlass: false)
    }
}

#Preview {
    VStack {
        FireWeatherRailView(level: .clear)
        FireWeatherRailView(level: .clear, showsResolvingPlaceholder: true)
        FireWeatherRailView(level: .elevated)
        FireWeatherRailView(level: .critical)
        FireWeatherRailView(level: .extreme)
        FireWeatherRailView(level: .critical, isOffline: true)
        FireWeatherRailView(level: nil, isOffline: true)
    }
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
