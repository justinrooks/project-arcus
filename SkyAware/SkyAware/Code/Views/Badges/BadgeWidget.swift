////
////  BadgeWidget.swift
////  SkyAware
////
////  Created by Justin Rooks on 7/24/25.
////
//
//import SwiftUI
//import WidgetKit
//
//// MARK: - Shared Model
//
//struct RiskEntry: TimelineEntry {
//    let date: Date
//    let badge: BadgeDefinition
//    let colorScheme: ColorScheme
//}
//
//// MARK: - Timeline Provider
//
//struct RiskTimelineProvider: TimelineProvider {
//    func placeholder(in context: Context) -> RiskEntry {
//        RiskEntry(date: Date(), badge: .placeholder(.enhanced), colorScheme: .light)
//    }
//
//    func getSnapshot(in context: Context, completion: @escaping (RiskEntry) -> Void) {
////        let entry = RiskEntry(date: Date(), badge: .placeholder(.mrgl), colorScheme: context.colorScheme ?? .light)
//        let entry = RiskEntry(date: Date(), badge: .placeholder(.marginal), colorScheme: .light)
//        completion(entry)
//    }
//
//    func getTimeline(in context: Context, completion: @escaping (Timeline<RiskEntry>) -> Void) {
//        // Replace this with live data integration
////        let entry = RiskEntry(date: Date(), badge: .placeholder(.danger), colorScheme: context.colorScheme ?? .light)
//        let entry = RiskEntry(date: Date(), badge: .placeholder(.high), colorScheme: .light)
//        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30)))
//        completion(timeline)
//    }
//}
//
//// MARK: - Widget View
//
//struct RiskBadgeWidgetView: View {
//    let badge: BadgeDefinition
//    let colorScheme: ColorScheme
//
//    var body: some View {
//        ZStack {
//            badgeBackground(for: badge.warningLevel)
//                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
//
//            VStack(spacing: 6) {
//                Image(systemName: iconName(for: badge.threat))
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 28, height: 28)
//                    .foregroundColor(iconColor(for: badge.warningLevel))
//
//                Text(badge.msg)
//                    .font(.system(size: 14, weight: .bold))
//                    .multilineTextAlignment(.center)
//                    .foregroundColor(labelColor)
//
//                Text(badge.summary)
//                    .font(.system(size: 10))
//                    .multilineTextAlignment(.center)
//                    .foregroundColor(labelColor)
//                    .padding(.horizontal, 4)
//            }
//            .aspectRatio(1, contentMode: .fit)
//            .frame(minWidth: 100, idealWidth: 135, maxWidth: 135,
//                   minHeight: 100, idealHeight: 135, maxHeight: 135)
//        }
//    }
//
//    // MARK: - Styling Helpers
//
//    func iconName(for threat: Threat) -> String {
//        switch threat {
//        case .tornado: return "tornado"
//        case .hail: return "circle.hexagonpath"
//        case .wind: return "wind"
//        default: return "checkmark.shield"
//        }
//    }
//
//    func iconColor(for level: WarningLevel) -> Color {
//        switch level {
//        case .marginal: return .green
//        case .slight: return .yellow
//        case .enhanced: return .orange
//        case .moderate: return .red
//        case .high: return .purple
//        case .safe: return .green
//        }
//    }
//
//    func badgeBackground(for level: WarningLevel) -> some View {
//        let base: Color
//        switch level {
//        case .marginal: base = Color.green.opacity(0.15)
//        case .slight: base = Color.yellow.opacity(0.15)
//        case .enhanced: base = Color.orange.opacity(0.15)
//        case .moderate: base = Color.red.opacity(0.15)
//        case .high: base = Color.purple.opacity(0.2)
//        case .safe: base = Color.green.opacity(0.1)
//        }
//        return base
//    }
//
//    var labelColor: Color {
//        colorScheme == .dark ? .white : .black
//    }
//}
//
//// MARK: - Widget Declaration
//
//struct RiskWidget: Widget {
//    let kind: String = "RiskWidget"
//
//    var body: some WidgetConfiguration {
//        StaticConfiguration(kind: kind, provider: RiskTimelineProvider()) { entry in
//            RiskBadgeWidgetView(badge: entry.badge, colorScheme: entry.colorScheme)
//        }
//        .configurationDisplayName("Severe Weather Risk")
//        .description("Shows your local severe storm risk at a glance.")
//        .supportedFamilies([.systemSmall])
//    }
//}
//
//#Preview {
//    RiskBadgeWidgetView(
//        badge: .placeholder(.enhanced),
//        colorScheme: .light
//    )
////    .previewContext(WidgetPreviewContext(family: .systemSmall))
//
//    RiskBadgeWidgetView(
//        badge: .placeholder(.high),
//        colorScheme: .dark
//    )
////    .previewContext(WidgetPreviewContext(family: .systemSmall))
//    RiskBadgeWidgetView(
//        badge: .placeholder(.safe),
//        colorScheme: .light
//    )
//    
//    RiskBadgeWidgetView(
//        badge: .placeholder(.safe),
//        colorScheme: .dark
//    )
//}
//
//
//// MARK: - Preview Helpers
//
//extension BadgeDefinition {
//    static func placeholder(_ level: WarningLevel) -> BadgeDefinition {
//        switch level {
//        case .marginal: return BadgeDefinition(msg: "Marginal", summary: "Isolated strong storms", warningLevel: .marginal)
//        case .slight: return BadgeDefinition(msg: "Slight", summary: "Scattered severe storms", warningLevel: .slight)
//        case .enhanced: return BadgeDefinition(msg: "Enhanced", summary: "Numerous severe storms", warningLevel: .enhanced)
//        case .moderate: return BadgeDefinition(msg: "Moderate", summary: "Widespread severe storms", warningLevel: .moderate)
//        case .high: return BadgeDefinition(msg: "High", summary: "Severe outbreak likely", warningLevel: .high)
//        case .safe: return BadgeDefinition(msg: "All Clear", summary: "No severe weather expected", warningLevel: .safe)
//        }
//    }
//}
