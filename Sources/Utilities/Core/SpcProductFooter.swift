//
//  SpcProductFooter.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/19/25.
//

import SwiftUI

struct SpcProductFooter: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let link: URL
    let validEnd: Date

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }
    
    var body: some View {
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
    }

    private var openInBrowserLink: some View {
        Link(destination: link) {
            Label("Open in browser", systemImage: "arrow.up.right.square")
                .font(.footnote.weight(.semibold))
        }
        .skyAwareGlassButtonStyle()
    }
}

#Preview("MD") {
    SpcProductFooter(link: MD.sampleDiscussionDTOs[1].link, validEnd: MD.sampleDiscussionDTOs[1].validEnd)
}

#Preview("Watch") {
    SpcProductFooter(link: Watch.sampleWatchRows[1].link, validEnd: Watch.sampleWatchRows[1].validEnd)
}
