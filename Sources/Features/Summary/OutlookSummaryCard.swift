//
//  OutlookSummaryCard.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct OutlookSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let outlook: ConvectiveOutlookDTO?
    let presentationState: ConvectiveOutlookPresentationState
    let todayContentState: TodayContentState
    let onBrowseAllOutlooks: (() -> Void)?
    
    @State private var navigateToFull = false

    init(
        outlook: ConvectiveOutlookDTO?,
        presentationState: ConvectiveOutlookPresentationState? = nil,
        todayContentState: TodayContentState = .current,
        onBrowseAllOutlooks: (() -> Void)? = nil
    ) {
        self.outlook = outlook
        self.presentationState = presentationState ?? (outlook == nil ? .loading : .populated(.current))
        self.todayContentState = todayContentState
        self.onBrowseAllOutlooks = onBrowseAllOutlooks
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

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            Text(summaryText)
                .font(.body)
                .lineSpacing(4)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)

            if let statusText = Self.statusText(for: presentationState) {
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Button(action: {
                guard outlook != nil else { return }
                navigateToFull = true
            }) {
                HStack(spacing: 8) {
                    Text("Read full outlook")
                    .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .skyAwareGlassButtonStyle()
            .disabled(outlook == nil)
        }
        .padding(18)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
        .placeholder(presentationState == .loading && todayContentState.showsResolvingSurface, animated: true)
        .navigationDestination(isPresented: $navigateToFull) {
            if let outlook {
                ConvectiveOutlookDetailView(outlook: outlook)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Label(titleText, systemImage: headerSymbolName)
                .sectionLabel()

            Spacer(minLength: 12)

            if adaptiveLayout.usesAccessibilityLayout == false,
               let onBrowseAllOutlooks {
                Button {
                    onBrowseAllOutlooks()
                } label: {
                    HStack(spacing: 6) {
                        Text("All Outlooks")
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .skyAwareChip(cornerRadius: SkyAwareRadius.chipCompact, tint: .white.opacity(0.10))
                }
                .buttonStyle(
                    SkyAwarePressableButtonStyle(
                        cornerRadius: SkyAwareRadius.chipCompact,
                        pressedScale: 0.985,
                        pressedOverlayOpacity: 0.08
                    )
                )
                .accessibilityHint("Opens the full outlook list.")
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
