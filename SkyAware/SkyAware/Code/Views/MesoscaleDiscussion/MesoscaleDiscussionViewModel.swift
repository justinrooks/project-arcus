////
////  MesoscaleDiscussionViewModel.swift
////  SkyAware
////
////  Created by Justin Rooks on 8/8/25.
////
//
//import Foundation
//import SwiftUI
//
//// MARK: - ViewModel (MVVM)
//@MainActor
//@Observable
//final class MesoscaleDiscussionViewModel {
//    var md: MesoscaleDiscussion
//
//    init(md: MesoscaleDiscussion) {
//        self.md = md
//    }
//
//    // Formatting helpers
//        private var dateTime: Date.FormatStyle {
//            .dateTime
//                .hour(.defaultDigits(amPM: .abbreviated))
//                .minute()
//                .weekday(.abbreviated)
//                .month(.abbreviated)
//                .day()
//                .year()
//        }
//
//        var title: String { "MESOSCALE DISCUSSION \(md.number)" }
//        var issuedText: String { "Issued " + md.issued.formatted(dateTime) }
//        var validRangeText: String { "\(md.validStart.formatted(dateTime)) – \(md.validEnd.formatted(dateTime))" }
//        var areasText: String { md.areasAffected }
//        var concerningText: String? { md.concerning }
//
//        var watchProbabilityText: String {
//            switch md.watchProbability {
//            case .percent(let p): return "\(p)%"
//            case .unlikely: return "Unlikely"
//            }
//        }
//
//        var watchProbabilityValue: Double { // 0...1 for the bar
//            switch md.watchProbability {
//            case .unlikely: return 0.05
//            case .percent(let p): return Double(p) / 100.0
//            }
//        }
//
//        // Primary threat heuristic for emphasis
//        var primaryThreatLabel: String? {
//            if let t = md.threats.tornadoStrength, t.lowercased() != "not expected" { return "Primary threat: Tornado (\(t))" }
//            if let hail = md.threats.hailRangeInches { return String(format: "Primary threat: Large hail (%.2g–%.2g in)", hail, hail) }
//            if let wind = md.threats.peakWindMPH { return "Primary threat: Wind (up to \(wind) mph)" }
//            return nil
//        }
//
//        func timeRemaining(now: Date = .now) -> TimeInterval { max(0, md.validEnd.timeIntervalSince(now)) }
//    }
//
//    // MARK: - Neutral/Utility palette
//    struct Neutral {
//        static let cardBG = Color(uiColor: .secondarySystemBackground)
//        static let stroke = Color.black.opacity(0.08)
//        static let labelSecondary = Color.secondary
//        static let accent = Color("AccentIndigo") // Provide in Assets or fallback below
//    }
