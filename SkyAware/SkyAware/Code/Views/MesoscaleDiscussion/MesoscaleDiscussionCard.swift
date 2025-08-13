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

struct MesoscaleDiscussionCard: View {
    var vm: MesoscaleDiscussionViewModel
    var layout: DetailLayout = .full
    var onShowMap: (() -> Void)? = nil
    
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
            if let concerning = vm.concerningText, !concerning.isEmpty { contextNote(concerning) }
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
            Text(vm.title)
                .font(headerFont.weight(.semibold))
                .textCase(.uppercase)
            Spacer()
            #warning("TODO: May need a better way. This is based off more 'convention' that the summary/sheet view is localized")
            InZonePill(inZone: layout == .sheet) // The sheet view is filtered, alters and full are not
        }
        .overlay(alignment: .bottomLeading) {
            Text(vm.issuedText)
                .font(.caption)
                .foregroundStyle(Neutral.labelSecondary)
                .offset(y: 26)
        }
        .padding(.bottom, 6)
    }
    
    private var pairs: some View {
        VStack(alignment: .leading, spacing: 10) {
            KeyValueRow(key: "Areas affected", value: vm.areasText)
            KeyValueRow(key: "Valid", value: vm.validRangeText)
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
                Text(vm.watchProbabilityText)
                    .font(.subheadline.weight(.semibold))
            }
            WatchProbabilityBar(progress: vm.watchProbabilityValue)
                .frame(height: 8)
                .clipShape(Capsule())
        }
        .padding(.top, layout == .sheet ? 2 : 4)
    }
    
    private var primaryThreat: some View {
        Group {
            if let label = vm.primaryThreatLabel {
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
                    GridRow { Text("Wind:").labelStyle(); Text(vm.md.threats.peakWindMPH.map { "Up to \($0) mph" } ?? "—").valueStyle() }
                    GridRow { Text("Hail:").labelStyle(); Text(vm.md.threats.hailRangeInches.map { String(format: "%.2g–%.2g in", $0.lowerBound, $0.upperBound) } ?? "—").valueStyle() }
                    GridRow { Text("Tornado:").labelStyle(); Text(vm.md.threats.tornadoStrength ?? "Not expected").valueStyle() }
                }
            }
        }
    }
    
    private var footer: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let remaining = vm.timeRemaining(now: ctx.date)
            HStack {
//                mapButton
//                Spacer()
                spcLink
                Spacer()
                ExpiryLabel(remaining: remaining)
            }
        }
    }
    
    private var mapButton: some View {
        Button {
            onShowMap?()
        } label: {
            Label("View on Map", systemImage: "map")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 6)
    }

    private var spcLink: some View {
        Link(destination: vm.md.link) {
            Label("Open on SPC", systemImage: "arrow.up.right.square")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 6)
    }

}


// MARK: - Preview
struct MesoscaleDiscussionCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: SpcProvider.previewData.meso[1]), layout: .sheet)
                .padding()
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: SpcProvider.previewData.meso[0]),
                layout: .full)
                .padding()
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
        }
    }
}
