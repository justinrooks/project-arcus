//
//  WatchDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct WatchDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let watch: WatchRowDTO
    let layout: DetailLayout
    let isExpanded: Bool
    
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    private var summarySpacing: CGFloat { isExpanded ? 10 : 8 }
    private var summaryAreaFont: Font { isExpanded ? .footnote.weight(.semibold) : .caption.weight(.semibold) }
    private var summaryLeadFont: Font { isExpanded ? .body.weight(.medium) : .callout.weight(.medium) }
    private var summaryLeadLineSpacing: CGFloat { isExpanded ? 4 : 3 }
    private var summaryBodyFont: Font { isExpanded ? .callout : .footnote }
    private var summaryBodyLineSpacing: CGFloat { isExpanded ? 4 : 3 }
    private var trimmedInstruction: String? {
        let instruction = watch.instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        return instruction?.isEmpty == false ? instruction : nil
    }

    private var trimmedHeadline: String? {
        let headline = watch.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        return headline.isEmpty ? nil : headline
    }

    private var trimmedDescription: String? {
        let description = watch.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }

    private var summaryLead: String? {
        trimmedInstruction ?? trimmedHeadline
    }

    private var summaryBody: String? {
        guard let description = trimmedDescription else { return nil }
        guard let lead = summaryLead else { return description }
        return description.localizedCaseInsensitiveCompare(lead) == .orderedSame ? nil : description
    }

    init(watch: WatchRowDTO, layout: DetailLayout, isExpanded: Bool = true) {
        self.watch = watch
        self.layout = layout
        self.isExpanded = isExpanded
    }
    
    var body: some View {
        Group {
            if layout == .sheet {
                sheetContent
            } else {
                LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                    headerCard

                    if let severeRiskTags = watch.severeRiskTags {
                        detailSection(title: "Severe Risk Tags", text: severeRiskTags, areTags: true)
                    }
                    detailSection(title: "Areas Affected", text: watch.areaSummary)
                    detailSection(title: "Full Description", text: watch.description)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var headerCard: some View {
        fullContent
            .padding()
            .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.12, shadowRadius: 16, shadowY: 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SpcProductHeader(
                layout: layout,
                title: watch.title,
                issued: watch.issued,
                validStart: watch.issued,
                validEnd: watch.validEnd,
                subtitle: watch.isUpdateMessage ? "Updated" : nil,
                inZone: false,
                sender: watch.sender
            )

            Divider().opacity(0.12)

            chips
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                StatusChip(kind: .severity(watch.severity))
                StatusChip(kind: .certainty(watch.certainty))
                StatusChip(kind: .urgency(watch.urgency))
            }
            .padding(.vertical, 2)
        }
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header

            if let instruction = trimmedInstruction {
                Text(instruction)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .accessibilityLabel("Instructions")
            }

            SpcProductFooter(link: watch.link, validEnd: watch.validEnd)
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header

            summarySection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            SpcProductFooter(link: watch.link, validEnd: watch.validEnd)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.12, shadowRadius: 16, shadowY: 8)
    }

    private var summarySection: some View {
        Group {
            if isExpanded {
                summaryContent(areaLineLimit: nil, leadLineLimit: nil, bodyLineLimit: nil)
            } else {
                ViewThatFits(in: .vertical) {
                    summaryContent(areaLineLimit: 2, leadLineLimit: nil, bodyLineLimit: nil)
                    summaryContent(areaLineLimit: 1, leadLineLimit: 4, bodyLineLimit: 7)
                    summaryContent(areaLineLimit: 1, leadLineLimit: 3, bodyLineLimit: 5)
                    summaryContent(areaLineLimit: 1, leadLineLimit: 2, bodyLineLimit: 3)
                    summaryContent(areaLineLimit: 1, leadLineLimit: 2, bodyLineLimit: 2)
                }
            }
        }
        .animation(SkyAwareMotion.disclosure(reduceMotion), value: isExpanded)
    }

    @ViewBuilder
    private func summaryContent(
        areaLineLimit: Int?,
        leadLineLimit: Int?,
        bodyLineLimit: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: summarySpacing) {
            if !watch.areaSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(watch.areaSummary)
                    .font(summaryAreaFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(areaLineLimit)
            }

            if let summaryLead {
                Text(summaryLead)
                    .font(summaryLeadFont)
                    .foregroundStyle(.primary)
                    .lineSpacing(summaryLeadLineSpacing)
                    .accessibilityLabel("Summary")
                    .lineLimit(leadLineLimit)
                    .truncationMode(.tail)
            }

            if let summaryBody {
                Text(summaryBody)
                    .font(summaryBodyFont)
                    .foregroundStyle(.secondary)
                    .lineSpacing(summaryBodyLineSpacing)
                    .lineLimit(bodyLineLimit)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: bodyLineLimit == nil)
            }
        }
    }

    private func detailSection(title: String, text: String, areTags: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .font(areTags ? .subheadline.weight(.semibold)  : .callout.monospaced())
                .foregroundStyle(areTags ? Color.tornadoRed  : .secondary)
        }
        .padding()
        .cardBackground(cornerRadius: SkyAwareRadius.content, shadowOpacity: 0.1, shadowRadius: 12, shadowY: 6)
    }
}

#Preview("Tornado Watch") {
    NavigationStack {
        ScrollView {
            WatchDetailView(watch: Watch.sampleWatchRows.last!, layout: .full)
                .navigationTitle("Weather Alert")
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
            WatchDetailView(watch: Watch.sampleWatchRows[3], layout: .full)
                .navigationTitle("Weather Alert")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}
