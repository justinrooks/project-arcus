//
//  MesoscaleDiscussionCard.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI
import Foundation

// MARK: - Card View (Less "weather-y")
enum DetailLayout { case full, sheet }

struct MesoscaleDiscussionContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let meso: MdDTO
    let layout: DetailLayout
    let isExpanded: Bool
    
    // Layout metrics
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    private var summaryFont: Font { isExpanded ? .callout : .footnote }
    private var summaryLineSpacing: CGFloat { isExpanded ? 4 : 3 }
    private var trimmedSummary: String? {
        let summary = meso.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? nil : summary
    }

    init(meso: MdDTO, layout: DetailLayout, isExpanded: Bool = true) {
        self.meso = meso
        self.layout = layout
        self.isExpanded = isExpanded
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SpcProductHeader(
                layout: layout,
                title: "Meso \(meso.number)",
                issued: meso.issued,
                validStart: meso.validStart,
                validEnd: meso.validEnd,
                subtitle: nil,
                inZone: false,
                sender: nil
            )
            
            Divider().opacity(0.12)
            
            if layout == .sheet { pairs }

            if let concerning = meso.concerning {
                contextNote(concerning)
            }
            
            probability
            primaryThreat

            if layout == .sheet {
                summarySection
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            SpcProductFooter(link: meso.link, validEnd: meso.validEnd)
            
            if layout == .full {
                Divider().opacity(0.12)
                Section(header: Text("Full Discussion")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                        Text(meso.summary)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
            }
        }
    }

    private var summarySection: some View {
        Group {
            if isExpanded {
                summaryContent(lineLimit: nil)
            } else {
                ViewThatFits(in: .vertical) {
                    summaryContent(lineLimit: nil)
                    summaryContent(lineLimit: 9)
                    summaryContent(lineLimit: 7)
                    summaryContent(lineLimit: 5)
                    summaryContent(lineLimit: 3)
                }
            }
        }
        .animation(SkyAwareMotion.disclosure(reduceMotion), value: isExpanded)
    }

    @ViewBuilder
    private func summaryContent(lineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trimmedSummary {
                Text(trimmedSummary)
                    .font(summaryFont)
                    .foregroundStyle(.secondary)
                    .lineSpacing(summaryLineSpacing)
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: lineLimit == nil)
            }
        }
    }
    
    // MARK: - Sections
    private var pairs: some View {
        VStack(alignment: .leading, spacing: 8) {
            KeyValueRow(key: "Areas affected", value: meso.areasAffected)
//            KeyValueRow(key: "Valid", value: "\(meso.validStart.shorten()) – \(meso.validEnd.shorten())")
        }
    }
    
    private func contextNote(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .skyAwareChip(cornerRadius: SkyAwareRadius.small, tint: .white.opacity(0.08))
    }
    
    private var probability: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Probability of Watch")
                    .font(.subheadline)
                Spacer()
                
                let watchInt = Int(meso.watchProbability)
                if watchInt > 0 {
                    Text("\(watchInt)%")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            WatchProbabilityBar(progress: (meso.watchProbability / 1))
                .frame(height: 8)
                .clipShape(Capsule())
        }
        .padding(.top, layout == .sheet ? 2 : 4)
    }
    
    private var primaryThreat: some View {
        Group {
            if let label = getPrimaryThreatLabel(for: meso){
                HStack {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .skyAwareChip(cornerRadius: SkyAwareRadius.tile, tint: .skyAwareAccent.opacity(0.15))
            } else {
                // Grid of simple label:value pairs when there is no standout threat
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        Text("Wind:").labelStyle()
                        Text(meso.threats?.peakWindMPH.map { "Up to \($0) mph" } ?? "—")
                            .valueStyle()
                    }
                    GridRow {
                        Text("Hail:").labelStyle()
                        Text(meso.threats?.hailRangeInches.map {
                            String(format: "Up to %.2g in", $0)
                        } ?? "—").valueStyle()
                    }
                    GridRow {
                        Text("Tornado:").labelStyle()
                        Text(meso.threats?.tornadoStrength ?? "Not expected")
                            .valueStyle()
                    }
                }
            }
        }
    }
}

struct MesoscaleDiscussionCard: View {
    let meso: MdDTO
    let layout: DetailLayout
    let isExpanded: Bool

    init(meso: MdDTO, layout: DetailLayout, isExpanded: Bool = true) {
        self.meso = meso
        self.layout = layout
        self.isExpanded = isExpanded
    }
    
    var body: some View {
        Group {
            if layout == .sheet {
                MesoscaleDiscussionContent(meso: meso, layout: layout, isExpanded: isExpanded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                MesoscaleDiscussionContent(meso: meso, layout: layout, isExpanded: isExpanded)
            }
        }
            .mesoscaleCardChrome(for: layout)
            .accessibilityElement(children: .contain)
    }
}
    
extension MesoscaleDiscussionContent {
    func getPrimaryThreatLabel(for m: MdDTO) -> String? {
        guard let threats = m.threats else {
            return nil
        }
        
        if let t = threats.tornadoStrength, t
            .lowercased() != "not expected" {
            return "Primary threat: Tornado (\(t))"
        }
        if let hail = threats.hailRangeInches {
            return "Primary threat: Large hail (Up to \(hail) in)"
        }// String(format: "Primary threat: Large hail (%.2g–%.2g in)", hail, hail) }
        if let wind = threats.peakWindMPH {
            return "Primary threat: Wind (Up to \(wind) mph)"
        }
        return nil
    }
}

// MARK: - Preview

#Preview("Full View") {
    NavigationStack {
        ScrollView{
            MesoscaleDiscussionCard(meso: MD.sampleDiscussionDTOs[1], layout: .full)
                .navigationTitle("Mesoscale Discussion")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}

#Preview("Sheet View") {
    NavigationStack {
        MesoscaleDiscussionCard(meso: MD.sampleDiscussionDTOs[1], layout: .sheet)
    }
}
