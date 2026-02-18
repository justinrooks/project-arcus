//
//  WatchDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct WatchDetailView: View {
    let watch: WatchRowDTO
    let layout: DetailLayout
    
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: sectionSpacing) {
            headerCard
            .padding()
            .cardBackground(cornerRadius: 24, shadowOpacity: 0.12, shadowRadius: 16, shadowY: 8)

            if layout == .full {
                detailSection(title: "Areas Affected", text: watch.areaSummary)
                detailSection(title: "Full Description", text: watch.description)
            }
        }
        .padding(.horizontal, layout == .sheet ? 0 : 4)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SpcProductHeader(
                title: watch.title,
                issued: watch.issued,
                validStart: watch.issued,
                validEnd: watch.validEnd,
                subtitle: watch.messageType == "UPDATE" ? "Updated" : nil,
                inZone: false,
                sender: watch.sender
            )

            Divider().opacity(0.12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    StatusChip(kind: .severity(watch.severity))
                    StatusChip(kind: .certainty(watch.certainty))
                    StatusChip(kind: .urgency(watch.urgency))
                }
                .padding(.vertical, 2)
            }

            if let instruction = watch.instruction {
                Text(instruction)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .accessibilityLabel("Instructions")
                    .lineLimit(layout == .sheet ? 3 : nil)
            }

            SpcProductFooter(link: watch.link, validEnd: watch.validEnd)
        }
    }

    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .cardBackground(cornerRadius: 20, shadowOpacity: 0.1, shadowRadius: 12, shadowY: 6)
    }
}

#Preview("Tornado Watch") {
    NavigationStack {
        ScrollView {
            WatchDetailView(watch: Watch.sampleWatchRows.last!, layout: .full)
                .navigationTitle("Weather Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}

#Preview("Severe Thunderstorm Watch") {
    NavigationStack {
        ScrollView {
            WatchDetailView(watch: Watch.sampleWatchRows[1], layout: .full)
                .navigationTitle("Weather Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}
