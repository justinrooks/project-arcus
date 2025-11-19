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
    let meso: MdDTO
    let layout: DetailLayout
    
    // Layout metrics
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SpcProductHeader(title: "Mesoscale Discussion", issued: meso.issued, validStart: meso.validStart, validEnd: meso.validEnd, subtitle: "MD 1913", inZone: false)
            
            Divider().opacity(0.12)
            
            if layout == .sheet { pairs }

            if let concerning = meso.concerning {
                contextNote(concerning)
            }
            
            probability
            primaryThreat

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
    
    // MARK: - Sections
//    private var header: some View {
//        VStack(alignment: .leading, spacing: layout == .sheet ? 2 : 4) {
//            HStack(alignment: .firstTextBaseline, spacing: 8) {
////                Text(layout == .full ? meso.areasAffected : meso.title)
//                Text("Mesoscale Discussion")
//                    .font(layout == .sheet ? .headline.weight(.semibold)
//                          : .title3.weight(.semibold))
//                    .textCase(.uppercase)
//                    .lineLimit(2)
//                    .minimumScaleFactor(0.85)
//                
//                Spacer()
//#warning("TODO: May need a better way. This is based off more 'convention' that the summary/sheet view is localized")
//            InZonePill(inZone: layout == .sheet) // The sheet view is filtered, alters and full are not
//            }
//            
//            Text("SPC MD 1913")
//                .font(.headline.weight(.semibold))
////                .textCase(.uppercase)
//                
//            Text("Issued: \(meso.issued.shorten())")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//            
//            Text("Valid: \(meso.validStart.shorten()) – \(meso.validEnd.shorten())")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//        }
//        .padding(.bottom, layout == .sheet ? 4 : 6)
//    }
    
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
            .background(
                RoundedRectangle(cornerRadius: SkyAwareRadius.small, style: .continuous).fill(Color.primary.opacity(0.04)))
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
                .background(Capsule().fill(Color.primary.opacity(0.06)))
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
    
//    private var footer: some View {
//        TimelineView(.periodic(from: .now, by: 60)) { ctx in
//            let remaining = timeRemaining(meso: meso, now: ctx.date)
//            HStack {
//                Link(destination: meso.link) {
//                    Label("Open on SPC", systemImage: "arrow.up.right.square")
//                        .font(.footnote.weight(.semibold))
//                        .foregroundStyle(.secondary)
//                }
//                
//                Spacer()
//                ExpiryLabel(remaining: remaining)
//            }
//            .padding(.top, 4)
//        }
//    }
}

struct MesoscaleDiscussionCard: View {
    let meso: MdDTO
    let layout: DetailLayout
    
    var body: some View {
        MesoscaleDiscussionContent(meso: meso, layout: layout)
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
    
//    func timeRemaining(meso: MdDTO, now: Date = .now) -> TimeInterval { max(0, meso.validEnd.timeIntervalSince(now)) }
}

// MARK: - Preview

#Preview("Full View") {
    NavigationStack {
        ScrollView{
            MesoscaleDiscussionCard(meso: MD.sampleDiscussionDTOs[1], layout: .full)
                .navigationTitle("SPC MD \(MD.sampleDiscussionDTOs[1].number, format: .number.grouping(.never))")
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
