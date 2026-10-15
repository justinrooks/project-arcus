//
//  OutlookSummaryCard.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//
//  Trial note: Outlook Summary has been removed from the Today composition
//  while this product change is evaluated. This card is intentionally unused.

import SwiftUI

struct OutlookSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let outlook: ConvectiveOutlookDTO?
    let presentationState: ConvectiveOutlookPresentationState
    let todayContentState: TodayContentState

    init(
        outlook: ConvectiveOutlookDTO?,
        presentationState: ConvectiveOutlookPresentationState? = nil,
        todayContentState: TodayContentState = .current
    ) {
        self.outlook = outlook
        self.presentationState = presentationState ?? (outlook == nil ? .loading : .populated(.current))
        self.todayContentState = todayContentState
    }

    private var titleText: String {
        "Outlook Summary"
    }

    private var summaryText: String {
        Self.outlookSummaryText(
            outlook: outlook,
            presentationState: presentationState
        )
    }

    private var headerSymbolName: String {
        if outlook != nil {
            return "sun.max.fill"
        }

        if presentationState == .loading {
            return "sun.horizon.fill"
        }

        return "sun.max.fill"
    }

    @ViewBuilder
    var body: some View {
        if let outlook {
            NavigationLink {
                ConvectiveOutlookDetailView(outlook: outlook)
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("summary-outlook-card")
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            Text(summaryText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)

            if let statusText = Self.statusText(for: presentationState) {
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .todayCardBackground(cornerRadius: SkyAwareRadius.card)
        .placeholder(presentationState == .loading && todayContentState.showsResolvingSurface, animated: true)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: headerSymbolName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(titleText)
                .todaySectionLabel()
            Spacer(minLength: 8)
            if outlook != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    static func outlookSummaryText(
        outlook: ConvectiveOutlookDTO?,
        presentationState: ConvectiveOutlookPresentationState
    ) -> String {
        if let summary = outlook?.summary {
            return summary
        }

        switch presentationState {
        case .loading:
            return "Checking outlook details…"
        case .unavailable:
            return "Outlook information is unavailable. Try again later."
        case .empty:
            return "No current convective outlooks were returned in the last confirmed update."
        case .populated:
            return "Outlook details will appear here when available."
        }
    }

    static func statusText(for presentationState: ConvectiveOutlookPresentationState) -> String? {
        switch presentationState.activity {
        case .refreshing:
            return "Checking for an updated outlook. Showing the last confirmed result."
        case .failed:
            return "Outlook could not be updated. Showing the last confirmed result."
        case .stale:
            return "Showing the last confirmed outlook while updates are unavailable."
        case .current, nil:
            return nil
        }
    }
}

#Preview {
    let dto:ConvectiveOutlookDTO = .init(
        title: "Outlook Test",
        link: URL(string: "https://www.weather.gov/severe/outlook/test")!,
        published: Date(),
        summary: "Isolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.",
        fullText: "...SUMMARY... \nIsolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.\n....20z UPDATE... \nThe only adjustment was a northward expansion of the 2% tornado and 5% wind risk probabilities across the far southwest WA coast. Recent imagery from KLGX shows a cluster of semi-discrete cells off the far southwest WA coast with weak, but discernible, mid-level rotation. Regional VWPs continue to show ample low-level shear, and surface temperatures are warming to near/slightly above the upper-end of the ensemble envelope. These kinematic/thermodynamic conditions may support at least a low-end wind and brief tornado threat along the coast.",
        day: 1,
        riskLevel: "mdt",
        issued: Date(),
        validUntil: Date()
    )
    
    return NavigationStack {
        OutlookSummaryCard(outlook: dto)
    }
}

#Preview("Outlook Summary - Resolving") {
    NavigationStack {
        OutlookSummaryCard(outlook: nil, presentationState: .unavailable)
            .padding()
    }
}

#Preview("Outlook Summary - Initial Resolve") {
    NavigationStack {
        OutlookSummaryCard(outlook: nil, presentationState: .loading, todayContentState: .noCacheResolving)
            .padding()
    }
}
