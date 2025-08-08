//
//  SevereWeatherThreat.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

enum SevereWeatherThreat: Comparable {
    case allClear
    case wind(probability: Double)
    case hail(probability: Double)
    case tornado(probability: Double)
    
    var probability: Double {
        switch self {
        case .allClear:
            return 0.0
        case .wind(let p), .hail(let p), .tornado(let p):
            return p
        }
    }
    
    var priority: Int {
        switch self {
        case .tornado: return 3
        case .hail: return 2
        case .wind: return 1
        case .allClear: return 0
        }
    }
    
    static func < (lhs: SevereWeatherThreat, rhs: SevereWeatherThreat) -> Bool {
        lhs.priority < rhs.priority
    }
    
    var id: Self { self }
    
    var iconName: String {
        switch self {
        case .allClear: return "checkmark.seal.fill"
        case .wind: return "wind"
        case .hail: return "cloud.hail.fill"
        case .tornado: return "tornado"
        }
    }
    
    func iconColor(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        switch self {
        case .allClear:
            colors = colorScheme == .dark
            ? [.green.opacity(0.4), .green.darken()]
            : [.green.opacity(0.2), .green]
        case .wind:
            colors = colorScheme == .dark
            ? [Color.windTeal.opacity(0.6), .teal.darken()]
            : [Color.windTeal.opacity(0.3), .teal]
        case .hail:
            colors = colorScheme == .dark
            ? [Color.hailBlue.opacity(0.6), .blue.darken()]
            : [Color.hailBlue.opacity(0.3), .blue]
        case .tornado:
            colors = colorScheme == .dark
            ? [Color.tornadoRed.opacity(0.6), .red.darken()]
            : [Color.tornadoRed.opacity(0.5), .red]
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var message: String {
        switch self {
        case .allClear: return "No Active Threats"
        case .wind: return "Wind"
        case .hail: return "Hail"
        case .tornado: return "Tornado"
        }
    }
    
    var summary: String {
        switch self {
        case .allClear: return "No severe threats expected"
        case .wind: return "Damaging wind possible"
        case .hail: return "1in or larger hail possible"
        case .tornado: return "Tornados are possible"
        }
    }
    
    var dynamicSummary: String {
        switch self {
        case .tornado: return "\(String(format: "%.0f%%", self.probability)) chance of tornadoes"
        case .hail: return "\(String(format: "%.0f%%", self.probability)) chance of large hail"
        case .wind: return "\(String(format: "%.0f%%", self.probability)) chance of damaging winds"
        case .allClear: return ""
        }
    }
}

extension SevereWeatherThreat {
    func with(probability newValue: Double) -> SevereWeatherThreat {
        switch self {
        case .allClear:
            return .allClear
        case .wind:
            return .wind(probability: newValue)
        case .hail:
            return .hail(probability: newValue)
        case .tornado:
            return .tornado(probability: newValue)
        }
    }
}
