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

// MARK: - Neutral/Utility palette
struct Neutral {
    static let cardBG = Color(uiColor: .secondarySystemBackground)
    static let stroke = Color.black.opacity(0.08)
    static let labelSecondary = Color.secondary
    static let accent = Color("AccentIndigo") // Provide in Assets or fallback below
}

struct MesoscaleDiscussionCard: View {
    let meso: MD
    var layout: DetailLayout = .full
    
    // Layout metrics
    private var hPad: CGFloat { layout == .sheet ? 0 : 18 }
    private var vPad: CGFloat { layout == .sheet ? 0 : 18 }
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    private var headerFont: Font { layout == .sheet ? .headline : .title3 }
    private var showCardBackground: Bool { layout == .full }
    private var cornerRadius: CGFloat { layout == .sheet ? 0 : 22 }
    private var showShadow: Bool { layout == .full }
    
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header
            Divider().opacity(0.12)
            pairs
            if let concerning = meso.concerning {
                contextNote(concerning)
            }
            probability
            primaryThreat
            footer
            Spacer()
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background(
            Group {
                if showCardBackground {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Neutral.cardBG)
                        .shadow(color: showShadow ? Neutral.stroke : .clear, radius: 10, y:2)
                }
            }
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Sections
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(meso.title)
                .font(headerFont.weight(.semibold))
                .textCase(.uppercase)
            Spacer()
            #warning("TODO: May need a better way. This is based off more 'convention' that the summary/sheet view is localized")
            InZonePill(inZone: layout == .sheet) // The sheet view is filtered, alters and full are not
        }
        .overlay(alignment: .bottomLeading) {
            Text("Issued \(meso.issued) ")// + meso.issued.formatted(dateTime))
                .font(.caption)
                .foregroundStyle(Neutral.labelSecondary)
                .offset(y: 26)
        }
        .padding(.bottom, 6)
    }
    
    private var pairs: some View {
        VStack(alignment: .leading, spacing: 10) {
            KeyValueRow(key: "Areas affected", value: meso.areasAffected)
            KeyValueRow(key: "Valid", value: "\(meso.validStart) – \(meso.validEnd)") //"\(md.validStart.formatted(dateTime)) – \(md.validEnd.formatted(dateTime))"
        }
    }
    
    private func contextNote(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.secondary.opacity(0.10)))
    }
    
    private var probability: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Probability of Watch")
                    .font(.subheadline)
                Spacer()
                if (meso.watchProbability == "" || meso.watchProbability == "") {
                    Text("\(meso.watchProbability)")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("\(meso.watchProbability)%")
                        .font(.subheadline.weight(.semibold))
                }
            }
            
            WatchProbabilityBar(progress: Double(meso.watchProbability) ?? 0)//getWatchProbability(for: meso))
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
                    GridRow { Text("Wind:").labelStyle(); Text(meso.threats?.peakWindMPH.map { "Up to \($0) mph" } ?? "—").valueStyle() }
                    GridRow { Text("Hail:").labelStyle(); Text(meso.threats?.hailRangeInches.map { String(format: "up to %.2g in", $0) } ?? "—").valueStyle() }
                    GridRow { Text("Tornado:").labelStyle(); Text(meso.threats?.tornadoStrength ?? "Not expected").valueStyle() }
                }
            }
        }
    }
    
    private var footer: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let remaining = timeRemaining(meso: meso, now: ctx.date)
            HStack {
//                mapButton
//                Spacer()
                spcLink
                Spacer()
                ExpiryLabel(remaining: remaining)
            }
        }
    }

    private var spcLink: some View {
        Link(destination: meso.link) {
            Label("Open on SPC", systemImage: "arrow.up.right.square")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 6)
    }

}

extension MesoscaleDiscussionCard {
    func getPrimaryThreatLabel(for m: MD) -> String? {
        guard let threats = m.threats else { return nil }
        
        if let t = threats.tornadoStrength, t.lowercased() != "not expected" { return "Primary threat: Tornado (\(t))" }
        if let hail = threats.hailRangeInches { return "Primary threat: Large hail (up to \(hail) in)" }// String(format: "Primary threat: Large hail (%.2g–%.2g in)", hail, hail) }
        if let wind = threats.peakWindMPH { return "Primary threat: Wind (up to \(wind) mph)" }
        return nil
    }
    
    func timeRemaining(meso: MD, now: Date = .now) -> TimeInterval { max(0, meso.validEnd.timeIntervalSince(now)) }
}

// MARK: - Preview

#Preview {
    let preview = Preview(MD.self)
    
    return NavigationStack {
        MesoscaleDiscussionCard(meso: MD.sampleDiscussions[1], layout: .full)
    }
}
