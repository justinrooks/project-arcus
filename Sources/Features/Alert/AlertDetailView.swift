//
//  AlertDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct AlertDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let alert: AlertDTO
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
        let instruction = alert.instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        return instruction?.isEmpty == false ? instruction : nil
    }

    private var trimmedHeadline: String? {
        let headline = alert.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        return headline.isEmpty ? nil : headline
    }

    private var trimmedDescription: String? {
        let description = alert.description.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    init(alert: AlertDTO, layout: DetailLayout, isExpanded: Bool = true) {
        self.alert = alert
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

                    if let severeRiskTags = alert.severeRiskTags {
                        detailSection(title: "Severe Risk Tags", text: severeRiskTags, areTags: true)
                    }
                    detailSection(title: "Areas Affected", text: alert.areaSummary)
                    detailSection(title: "Full Description", text: alert.description)
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
                title: alert.title,
                issued: alert.issued,
                validStart: alert.issued,
                validEnd: alert.validEnd,
                subtitle: alert.isUpdateMessage ? "Updated" : nil,
                inZone: false,
                sender: alert.sender
            )

            Divider().opacity(0.12)

            chips
        }
    }

    private var chips: some View {
        Group {
            if adaptiveLayout.usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: 8) {
                    StatusChip(kind: .severity(alert.severity))
                    StatusChip(kind: .certainty(alert.certainty))
                    StatusChip(kind: .urgency(alert.urgency))
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        StatusChip(kind: .severity(alert.severity))
                        StatusChip(kind: .certainty(alert.certainty))
                        StatusChip(kind: .urgency(alert.urgency))
                    }
                    .padding(.vertical, 2)
                }
            }
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
            }

            SpcProductFooter(link: alert.link, validEnd: alert.validEnd)
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header

            summarySection
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            SpcProductFooter(link: alert.link, validEnd: alert.validEnd)
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
            if !alert.areaSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(alert.areaSummary)
                    .font(summaryAreaFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(areaLineLimit)
            }

            if let summaryLead {
                Text(summaryLead)
                    .font(summaryLeadFont)
                    .foregroundStyle(.primary)
                    .lineSpacing(summaryLeadLineSpacing)
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
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
        .cardBackground(cornerRadius: SkyAwareRadius.content, shadowOpacity: 0.1, shadowRadius: 12, shadowY: 6)
    }
}

#Preview("Tornado Watch") {
    NavigationStack {
        ScrollView {
            AlertDetailView(alert: Watch.sampleWatchRows.last!, layout: .full)
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
            AlertDetailView(alert: Watch.sampleWatchRows[3], layout: .full)
                .navigationTitle("Weather Alert")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}
