//
//  SpcProductFooter.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/19/25.
//

import SwiftUI

struct SpcProductFooter: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL

    let link: URL
    let validEnd: Date?
    @State private var webRoute: WebContentRoute?

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }
    
    var body: some View {
        Group {
            if let validEnd {
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    let remaining = max(0, validEnd.timeIntervalSince(ctx.date))
                    Group {
                        if adaptiveLayout.usesAccessibilityLayout {
                            VStack(alignment: .leading, spacing: 8) {
                                openInBrowserLink
                                ExpiryLabel(remaining: remaining)
                            }
                        } else {
                            HStack {
                                openInBrowserLink
                                Spacer()
                                ExpiryLabel(remaining: remaining)
                            }
                        }
                    }
                }
            } else {
                openInBrowserLink
            }
        }
    }

    private var openInBrowserLink: some View {
        Button {
            switch WebContentPolicy.decision(for: link) {
            case .inApp:
                webRoute = WebContentRoute(
                    url: link,
                    title: "SPC Product",
                    sourceName: "Storm Prediction Center"
                )
            case .external:
                openURL(link)
            case .unsupported:
                break
            }
        } label: {
            Label("Open in browser", systemImage: "arrow.up.right.square")
                .font(.footnote.weight(.semibold))
        }
        .skyAwareGlassButtonStyle()
        .sheet(item: $webRoute) { route in
            WebContentView(route: route)
        }
    }
}

#Preview("MD") {
    SpcProductFooter(link: MD.sampleDiscussionDTOs[1].link, validEnd: MD.sampleDiscussionDTOs[1].validEnd)
}

#Preview("Watch") {
    SpcProductFooter(link: Watch.sampleWatchRows[1].link, validEnd: Watch.sampleWatchRows[1].validEnd)
}
