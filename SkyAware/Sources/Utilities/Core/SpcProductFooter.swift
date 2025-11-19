//
//  SpcProductFooter.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/19/25.
//

import SwiftUI

struct SpcProductFooter: View {
    let link: URL
    let validEnd: Date
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let remaining = max(0, validEnd.timeIntervalSince(ctx.date))
            HStack {
                Link(destination: link) {
                    Label("Open on SPC", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                ExpiryLabel(remaining: remaining)
            }
        }
    }
}

#Preview {
    SpcProductFooter(link: MD.sampleDiscussionDTOs[1].link, validEnd: MD.sampleDiscussionDTOs[1].validEnd)
}
