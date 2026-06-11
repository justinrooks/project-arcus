//
//  ConvectiveOutlookDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct ConvectiveOutlookDetailPresentation: Sendable, Equatable {
    struct MetadataChip: Sendable, Equatable, Identifiable {
        let title: String
        let icon: String

        var id: String {
            "\(icon)|\(title)"
        }
    }

    let headerTitle: String
    let navigationTitle: String
    let metadataChips: [MetadataChip]
    let validUntil: Date?

    init(outlook: ConvectiveOutlookDTO) {
        let day = Self.derivedDay(for: outlook)
        headerTitle = day.map { "Day \($0) Convective Outlook" } ?? outlook.title
        navigationTitle = day.map { "Day \($0) Outlook" } ?? "Outlook Details"
        validUntil = outlook.validUntil
        metadataChips = Self.makeMetadataChips(for: outlook, derivedDay: day)
    }

    private static func makeMetadataChips(
        for outlook: ConvectiveOutlookDTO,
        derivedDay: Int?
    ) -> [MetadataChip] {
        var chips: [MetadataChip] = [
            MetadataChip(
                title: "Published \(outlook.published.relativeDate())",
                icon: "clock.arrow.circlepath"
            )
        ]

        if let derivedDay {
            chips.append(MetadataChip(title: "Day \(derivedDay)", icon: "calendar"))
        }

        if let risk = outlook.riskLevel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !risk.isEmpty {
            chips.append(
                MetadataChip(
                    title: ConvectiveOutlookDetailPresentation.sentenceCaseRiskLevel(risk),
                    icon: "exclamationmark.triangle"
                )
            )
        }

        return chips
    }

    private static func derivedDay(for outlook: ConvectiveOutlookDTO) -> Int? {
        outlook.day ?? parsedDay(from: outlook.title)
    }

    private static func parsedDay(from title: String) -> Int? {
        if title.contains("Day 1") {
            return 1
        }
        if title.contains("Day 2") {
            return 2
        }
        if title.contains("Day 3") {
            return 3
        }
        return nil
    }

    static func sentenceCaseRiskLevel(_ risk: String) -> String {
        let normalized = risk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return normalized }

        switch normalized.uppercased() {
        case "MRGL": return "Marginal"
        case "SLGT": return "Slight"
        case "ENH": return "Enhanced"
        case "MDT": return "Moderate"
        case "HIGH": return "High"
        default:
            let lowercase = normalized.lowercased()
            return lowercase.prefix(1).uppercased() + lowercase.dropFirst()
        }
    }
}

struct ConvectiveOutlookDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let outlook: ConvectiveOutlookDTO
    
    private let sectionSpacing: CGFloat = 14
    
    private var presentation: ConvectiveOutlookDetailPresentation {
        ConvectiveOutlookDetailPresentation(outlook: outlook)
    }

    private var displayTitle: String {
        presentation.headerTitle
    }
    
    private var issuedDate: Date {
        outlook.issued ?? outlook.published
    }
    
    private var subtitle: String? {
        guard let risk = outlook.riskLevel?.trimmingCharacters(in: .whitespacesAndNewlines), !risk.isEmpty else {
            return nil
        }
        return "Risk: \(sentenceCaseRiskLevel(risk))"
    }
    
    private var fullDiscussion: String {
        if let clean = outlook.cleanText?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty {
            return clean
        }
        return outlook.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerCard
                    .padding()
                    .cardBackground(
                        cornerRadius: SkyAwareRadius.card,
                        shadowOpacity: 0.12,
                        shadowRadius: 16,
                        shadowY: 8,
                        allowsGlass: false
                    )
                
                detailSection(title: "Summary", text: outlook.summary)
                
                if !fullDiscussion.isEmpty {
                    detailSection(title: "Full Discussion", text: fullDiscussion)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        .navigationTitle(presentation.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SpcProductHeader(
                title: displayTitle,
                issued: issuedDate,
                validStart: issuedDate,
                validEnd: presentation.validUntil,
                subtitle: subtitle,
                inZone: false,
                sender: "Storm Prediction Center"
            )
            
            Divider().opacity(0.12)

            if adaptiveLayout.usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: 8) {
                    metadataChips
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        metadataChips
                    }
                    .padding(.vertical, 2)
                }
            }
            
            SpcProductFooter(link: outlook.link, validEnd: presentation.validUntil)
        }
    }

    @ViewBuilder
    private var metadataChips: some View {
        ForEach(presentation.metadataChips) { chip in
            OutlookMetaChip(title: chip.title, icon: chip.icon)
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .cardBackground(
            cornerRadius: SkyAwareRadius.content,
            shadowOpacity: 0.10,
            shadowRadius: 12,
            shadowY: 6,
            allowsGlass: false
        )
    }

    private func sentenceCaseRiskLevel(_ risk: String) -> String {
        ConvectiveOutlookDetailPresentation.sentenceCaseRiskLevel(risk)
    }
}

private struct OutlookMetaChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let icon: String

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(adaptiveLayout.usesAccessibilityLayout ? 2 : 1)
        }
        .frame(maxWidth: adaptiveLayout.usesAccessibilityLayout ? .infinity : nil, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .skyAwareChip(cornerRadius: SkyAwareRadius.hero, tint: .white.opacity(0.10), interactive: true)
    }
}

#Preview {
    NavigationStack {
        ConvectiveOutlookDetailView(outlook: ConvectiveOutlook.sampleOutlookDtos[0])
            .navigationTitle("Outlook Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview("Partial Metadata") {
    let outlook = ConvectiveOutlookDTO(
        title: "Convective Outlook",
        link: URL(string: "https://www.spc.noaa.gov/products/outlook/day4otlk.html")!,
        published: Date(),
        summary: "Summary",
        fullText: "Full text",
        day: nil,
        riskLevel: nil,
        issued: nil,
        validUntil: nil
    )

    NavigationStack {
        ConvectiveOutlookDetailView(outlook: outlook)
            .navigationTitle("Outlook Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
