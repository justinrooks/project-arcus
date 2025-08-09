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
            InZonePill(inZone: vm.md.userIsInPolygon)
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
                Spacer()
                ExpiryLabel(remaining: remaining)
            }
        }
    }
}


// MARK: - Preview
struct MesoscaleDiscussionCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: SpcProvider.previewData.meso[1]), layout: .sheet)
                .padding()
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .light)
            MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: SpcProvider.previewData.meso[0]),
                layout: .full)
                .padding()
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
        }
    }
}

//    // Formatting helpers
//    private var dateTime: Date.FormatStyle {
//        .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute().weekday(.abbreviated).month(.abbreviated).day().year()
//    }
//
//    var title: String { "Mesoscale Discussion \(md.number)" }
//    var issuedText: String { md.issued.formatted(dateTime) }
//    var validRangeText: String { "\(md.validStart.formatted(dateTime)) – \(md.validEnd.formatted(dateTime))" }
//    var areasText: String { md.areasAffected }
//    var concerningText: String? { md.concerning }
//
//    var watchProbabilityText: String {
//        switch md.watchProbability {
//        case .percent(let p): return "\(p)%"
//        case .unlikely: return "Unlikely"
//        }
//    }
//
//    var watchProbabilitySeverity: Severity {
//        switch md.watchProbability {
//        case .unlikely: return .low
//        case .percent(let p):
//            switch p {
//            case 0..<20: return .low
//            case 20..<40: return .elevated
//            case 40..<60: return .moderate
//            case 60..<80: return .high
//            default: return .extreme
//            }
//        }
//    }
//
//    // Primary threat heuristic for emphasis (optional)
//    var primaryThreatLabel: String? {
//        // prefer tornado mention if present
//        if let t = md.threats.tornadoStrength, t.lowercased() != "not expected" { return "Tornado: \(t)" }
//        if let wind = md.threats.peakWindMPH { return "Wind: up to \(wind) mph" }
//        if let hail = md.threats.hailRangeInches { return String(format: "Hail: %.2g–%.2g in", hail.lowerBound, hail.upperBound) }
//        return nil
//    }
//
//    func timeRemaining(now: Date = .now) -> TimeInterval { max(0, md.validEnd.timeIntervalSince(now)) }
//}
//
//// MARK: - Severity palette
//enum Severity { case low, elevated, moderate, high, extreme }
//extension Severity {
//    var tint: Color {
//        switch self {
//        case .low: return .green
//        case .elevated: return .yellow
//        case .moderate: return .orange
//        case .high: return .red
//        case .extreme: return .purple
//        }
//    }
//    var background: Color { tint.opacity(0.15) }
//}
//
//// MARK: - Card View
//struct MesoscaleDiscussionCard: View {
//    @ObservedObject var vm: MesoscaleDiscussionViewModel
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 15) {
//            header
//            Divider()
//            meta
//            Divider()
//            concerning
//            probability
//            Divider()
//            threats
//            if let primary = vm.primaryThreatLabel { emphasis(label: primary, icon: "wind") }
////            locationBanner
//            expiry
//        }
//        .padding(18)
//        .background(.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
//        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
//        .accessibilityElement(children: .contain)
//    }
//
//    // MARK: Subviews
//    private var header: some View {
//        HStack(alignment: .firstTextBaseline) {
//            Text(vm.title)
//                .font(.headline)
//            Spacer()
//            Label(vm.issuedText, systemImage: "clock")
//                .labelStyle(.titleAndIcon)
//                .font(.caption)
//                .foregroundStyle(.secondary)
//                .accessibilityLabel("Issued \(vm.issuedText)")
//        }
//    }
//
//    private var meta: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            HStack(alignment: .top, spacing: 8) {
//                Text("Areas")
//                    .font(.caption).foregroundStyle(.secondary)
//                    .frame(width: 50, alignment: .leading)
//                Text(vm.areasText)
//                    .font(.subheadline)
//                    .lineLimit(2)
//            }
//            HStack(spacing: 8){
//                Spacer()
//                locationBanner
//            }
//            HStack(alignment: .top, spacing: 8) {
//                Text("Valid")
//                    .font(.caption).foregroundStyle(.secondary)
//                    .frame(width: 50, alignment: .leading)
//                Text(vm.validRangeText)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//        }
//    }
//
//    private var concerning: some View {
//        Group {
//            if let text = vm.concerningText, !text.isEmpty {
//                Text(text)
//                    .font(.callout.weight(.semibold))
//                    .padding(.vertical, 7)
//                    .padding(.horizontal, 10)
//                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.green, lineWidth: 1))
//                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
//            }
//        }
//        .accessibilityLabel("Context: \(vm.concerningText ?? "None")")
//    }
//
//    private var probability: some View {
//        HStack(spacing: 10) {
//            Image(systemName: "exclamationmark.triangle")
//                .foregroundStyle(vm.watchProbabilitySeverity.tint)
//            Text("Watch Probability")
//                .font(.subheadline)
//            Spacer(minLength: 8)
//            ProbabilityPill(text: vm.watchProbabilityText, severity: vm.watchProbabilitySeverity)
//        }
//        .accessibilityElement(children: .combine)
//        .accessibilityLabel("Probability of Watch Issuance \(vm.watchProbabilityText)")
//    }
//
//    private var threats: some View {
//        HStack(spacing: 16) {
//            ThreatBadge(icon: "wind", label: "Wind", value: vm.md.threats.peakWindMPH.map { "Up to \($0) mph" } ?? "—")
//            ThreatBadge(icon: "cloud.hail", label: "Hail", value: vm.md.threats.hailRangeInches.map { String(format: "%.2g–%.2g in", $0.lowerBound, $0.upperBound) } ?? "—")
//            ThreatBadge(icon: "tornado", label: "Tornado", value: vm.md.threats.tornadoStrength ?? "Not expected")
//        }
//    }
//
//    private func emphasis(label: String, icon: String) -> some View {
////        Group {
////            if let text = vm.concerningText, !text.isEmpty {
////                Text(text)
////                    .font(.callout.weight(.semibold))
////                    .padding(.vertical, 7)
////                    .padding(.horizontal, 10)
////                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.green, lineWidth: 1))
////                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
////            }
////        }
////        .accessibilityLabel("Context: \(vm.concerningText ?? "None")")
//        HStack(spacing: 8) {
//            Image(systemName: icon)
//            Text(label)
//                .font(.footnote.weight(.semibold))
//        }
////        .padding(.vertical, 7)
////        .padding(.horizontal, 10)
////        .background(Severity.moderate.background, in: Capsule())
////        .foregroundStyle(Severity.moderate.tint)
//        .font(.callout.weight(.semibold))
//        .padding(.vertical, 7)
//        .padding(.horizontal, 10)
//        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Severity.moderate.tint, lineWidth: 1))
//        .background(RoundedRectangle(cornerRadius: 10).fill(Severity.moderate.tint.opacity(0.08)))
//        .accessibilityLabel("Primary threat: \(label)")
//    }
//
//    private var locationBanner: some View {
//        Group {
//            if vm.md.userIsInPolygon {
//                Label("You are inside the affected area", systemImage: "checkmark.circle")
//                    .foregroundStyle(.green)
//                    .font(.caption)
//            } else {
//                Label("You are outside the affected area", systemImage: "xmark.circle")
//                    .foregroundStyle(.secondary)
//                    .font(.caption)
//            }
//        }
//        .accessibilityHint("Tap to view on map")
//    }
//
//    private var expiry: some View {
//        TimelineView(.periodic(from: .now, by: 60)) { context in
//            let remaining = vm.timeRemaining(now: context.date)
//            ExpiryLabel(remaining: remaining)
//        }
//    }
//}
//
//// MARK: - Components
//struct ThreatBadge: View {
//    let icon: String
//    let label: String
//    let value: String
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            HStack(spacing: 6) {
//                Image(systemName: icon)
//                    .font(.title3)
//                Text(label)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//            Text(value)
//                .font(.footnote.weight(.semibold))
//        }
//        .accessibilityElement(children: .combine)
//        .accessibilityLabel("\(label): \(value)")
//    }
//}
//
//struct ProbabilityPill: View {
//    let text: String
//    let severity: Severity
//
//    var body: some View {
//        Text(text)
//            .font(.caption.weight(.semibold))
//            .padding(.vertical, 7)
//            .padding(.horizontal, 10)
//            .background(severity.background, in: Capsule())
//            //.foregroundStyle(severity.tint)
//    }
//}
//
//struct ExpiryLabel: View {
//    let remaining: TimeInterval // seconds
//
//    private var text: String {
//        if remaining <= 0 { return "Expired" }
//        let minutes = Int(remaining / 60) % 60
//        let hours = Int(remaining / 3600)
//        if hours > 0 { return "Expires in \(hours)h \(minutes)m" }
//        return "Expires in \(minutes)m"
//    }
//
//    var body: some View {
//        HStack(spacing: 8) {
//            Image(systemName: remaining <= 0 ? "hourglass" : "hourglass.bottomhalf.fill")
//            Text(text)
//                .font(.caption)
//                .foregroundStyle(remaining <= 0 ? .secondary : .primary)
//        }
//        .accessibilityLabel(text)
//    }
//}
//
//// MARK: - Preview with sample data
//struct MesoscaleDiscussionCard_Previews: PreviewProvider {
//    static var previews: some View {
//        let md = MesoscaleDiscussion_temp(
//            number: 1895,
//            issued: Date(),
//            validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date()) ?? Date(),
//            validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
//            areasAffected: "Western SD… northeast WY… and far southeast MT",
//            concerning: "Severe potential… Watch unlikely",
//            watchProbability: .percent(5),
//            threats: MDThreats(peakWindMPH: 60, hailRangeInches: 1.5...2.5, tornadoStrength: "Not expected"),
//            userIsInPolygon: true
//        )
//        MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: md))
//            .padding()
//            .previewLayout(.sizeThatFits)
//            .environment(\.colorScheme, .light)
//        MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: md))
//            .padding()
//            .previewLayout(.sizeThatFits)
//            .environment(\.colorScheme, .dark)
//    }
//}
//
//// MARK: - Semantic background helper
//extension ShapeStyle where Self == Color {
//    static var secondarySystemBackground: Color {
//        #if os(iOS)
//        return Color(uiColor: .secondarySystemBackground)
//        #else
//        return Color(nsColor: .windowBackgroundColor)
//        #endif
//    }
//}
