////
////  WeatherRisk.swift
////  SkyAware
////
////  Created by Justin Rooks on 9/27/25.
////
//
//import SwiftUI
//import CoreLocation
//
///// One UI model for both categorical (TSTM → HIGH) and severe (tornado/hail/wind).
///// Storage should keep raw primitives; this is for views / VMs.
//enum WeatherRisk: Sendable, Identifiable, Comparable, Codable {
//    case none
//    case categorical(level: StormRiskLevel)                 // e.g., .slight, .moderate
//    case severe(type: SevereType, probability: Double, isSignificant: Bool = false)
//
//    var id: String {
//        switch self {
//        case .none: return "none"
//        case .categorical(let level): return "cat:\(level.rawValue)"
//        case .severe(let t, let p, let sig): return "sev:\(t.rawValue):\(Int(round(p*100)))%:sig:\(sig)"
//        }
//    }
//
//    // MARK: - Ordering policy
//    // Default: any severe threat outranks categorical; tornado > hail > wind.
//    // Tweak tuple if you want HIGH to outrank low-prob severe.
//    static func < (lhs: WeatherRisk, rhs: WeatherRisk) -> Bool {
//        lhs.priorityTuple < rhs.priorityTuple
//    }
//
//    private var priorityTuple: (tier: Int, sub: Int, prob: Int) {
//        switch self {
//        case .none:
//            return (0, 0, 0)
//        case .categorical(let level):
//            // Give categorical a tier below severe; sub-order by level rawValue.
//            return (1, level.rawValue, 0)
//        case .severe(let type, let p, _):
//            // Highest tier for severe; tornado > hail > wind; then by probability.
//            let threatRank: Int = {
//                switch type {
//                case .tornado: return 3
//                case .hail:    return 2
//                case .wind:    return 1
//                }
//            }()
//            return (2, threatRank, Int((p * 100.0).rounded()))
//        }
//    }
//
//    // MARK: - Projections & niceties
//
//    var probability: Double? {
//        switch self {
//        case .severe(_, let p, _): return p
//        default: return nil
//        }
//    }
//
//    var isSignificant: Bool {
//        switch self {
//        case .severe(_, _, let sig): return sig
//        default: return false
//        }
//    }
//
//    var abbreviation: String {
//        switch self {
//        case .none: return "clr"
//        case .categorical(let level): return level.abbreviation
//        case .severe(let t, _, let sig):
//            let base = t.abbreviation
//            return sig ? base + "-sig" : base
//        }
//    }
//
//    var iconName: String {
//        switch self {
//        case .none: return "checkmark.seal.fill"
//        case .categorical(let level): return level.iconName
//        case .severe(let t, _, _):
//            switch t {
//            case .wind:    return "wind"
//            case .hail:    return "cloud.hail.fill"
//            case .tornado: return "tornado"
//            }
//        }
//    }
//
//    var message: String {
//        switch self {
//        case .none: return "All Clear"
//        case .categorical(let level): return level.message
//        case .severe(let t, _, _):
//            switch t {
//            case .wind:    return "Wind"
//            case .hail:    return "Hail"
//            case .tornado: return "Tornado"
//            }
//        }
//    }
//
//    var summary: String {
//        switch self {
//        case .none: return "No severe threats expected"
//        case .categorical(let level): return level.summary
//        case .severe(let t, _, _):
//            switch t {
//            case .wind:    return "Damaging wind possible"
//            case .hail:    return "1in or larger hail possible"
//            case .tornado: return "Tornadoes are possible"
//            }
//        }
//    }
//
//    var dynamicSummary: String {
//        switch self {
//        case .none: return ""
//        case .categorical(let level): return level.summary
//        case .severe(let t, let p, _):
//            let pct = String(format: "%.0f%%", p)
//            switch t {
//            case .wind:    return "\(pct) chance of damaging winds"
//            case .hail:    return "\(pct) chance of large hail"
//            case .tornado: return "\(pct) chance of tornadoes"
//            }
//        }
//    }
//
//    func iconColor(for colorScheme: ColorScheme) -> LinearGradient {
//        switch self {
//        case .none:
//            let colors = colorScheme == .dark ? [Color.green.opacity(0.4), .green.darken()]
//                                              : [Color.green.opacity(0.2), .green]
//            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
//
//        case .categorical(let level):
//            return level.iconColor(for: colorScheme)
//
//        case .severe(let t, _, _):
//            let colors: [Color]
//            switch t {
//            case .wind:
//                colors = colorScheme == .dark ? [Color.windTeal.opacity(0.6), .teal.darken()]
//                                              : [Color.windTeal.opacity(0.3), .teal]
//            case .hail:
//                colors = colorScheme == .dark ? [Color.hailBlue.opacity(0.6), .blue.darken()]
//                                              : [Color.hailBlue.opacity(0.3), .blue]
//            case .tornado:
//                colors = colorScheme == .dark ? [Color.tornadoRed.opacity(0.6), .red.darken()]
//                                              : [Color.tornadoRed.opacity(0.5), .red]
//            }
//            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
//        }
//    }
//}
//
//// MARK: - Threat type used by unified enum
//enum SevereType: String, Codable, Sendable, CaseIterable, Identifiable {
//    case wind, hail, tornado
//    var id: Self { self }
//
//    var abbreviation: String {
//        switch self {
//        case .wind: return "wind"
//        case .hail: return "hail"
//        case .tornado: return "torn"
//        }
//    }
//}
//
//// MARK: - Adapters from your existing enums
//
//extension WeatherRisk {
//    init(from level: StormRiskLevel) {
//        self = level == .allClear ? .none : .categorical(level: level)
//    }
//
//    init(from threat: SevereWeatherThreat) {
//        switch threat {
//        case .allClear:
//            self = .none
//        case .wind(let p):
//            self = .severe(type: .wind, probability: p, isSignificant: false)
//        case .hail(let p):
//            self = .severe(type: .hail, probability: p, isSignificant: false)
//        case .tornado(let p):
//            self = .severe(type: .tornado, probability: p, isSignificant: false)
//        }
//    }
//
//    func with(probability newValue: Double) -> WeatherRisk {
//        switch self {
//        case .severe(let t, _, let sig): return .severe(type: t, probability: newValue, isSignificant: sig)
//        default: return self
//        }
//    }
//}
