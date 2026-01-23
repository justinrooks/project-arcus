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
    
    // Layout metrics
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // 🔷 Header
            SpcProductHeader(title: "\(watch.title)", issued: watch.issued, validStart: watch.issued, validEnd: watch.validEnd, subtitle: watch.messageType == "UPDATE" ? "Updated" : nil, inZone: false, sender: watch.sender)
            
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
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Instructions")
                    .lineLimit(layout == .sheet ? 3 : nil)
                
            }
            SpcProductFooter(link: watch.link, validEnd: watch.validEnd)
            
            if layout == .full {
                Section(header: Text("Areas Effected")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                        Text(watch.areaSummary)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                // 📝 Full Discussion
                Divider().opacity(0.12)
                Section(header: Text("Full Description")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                        Text(watch.description)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
            }
        }
        .padding()
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
