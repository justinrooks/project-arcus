//
//  StormRiskLevel.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

enum StormRiskLevel: Int, CaseIterable, Identifiable, Comparable, Codable {
    case allClear = 0
    case thunderstorm = 1
    case marginal = 2
    case slight = 3
    case enhanced = 4
    case moderate = 5
    case high = 6
    
    var id: Self { self }
    
    static func < (lhs: StormRiskLevel, rhs: StormRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var iconName: String {
        switch self {
        case .allClear: return "checkmark.seal.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .marginal: return "exclamationmark.circle.fill"
        case .slight: return "exclamationmark.triangle.fill"
        case .enhanced: return "bolt.fill"
        case .moderate: return "exclamationmark.octagon.fill"
        case .high: return "flame.fill"
        }
    }
    
    var message: String {
        switch self {
        case .allClear: return "Clear Skies"
        case .thunderstorm: return "Thunderstorms"
        case .marginal: return "Marginal Risk"
        case .slight: return "Slight Risk"
        case .enhanced: return "Enhanced Risk"
        case .moderate: return "Moderate Risk"
        case .high: return "High Risk"
        }
    }
    
    var summary: String {
        switch self {
        case .allClear: return "No severe storms expected"
        case .thunderstorm: return "Chance of thunderstorms"
        case .marginal: return "Low risk, but some stronger storms possible"
        case .slight: return "Chance for a few strong storms"
        case .enhanced: return "Several severe storms are possible"
        case .moderate: return "Widespread severe storms expected"
        case .high: return "Severe outbreak likely — stay alert"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .allClear: return "clr"
        case .thunderstorm: return "tstm"
        case .marginal: return "mrgl"
        case .slight: return "slgt"
        case .enhanced: return "enh"
        case .moderate: return "mdt"
        case .high: return "high"
        }
    }
    
    init(abbreviation: String) {
        switch abbreviation.lowercased() {
        case "tstm": self = .thunderstorm
        case "mrgl": self = .marginal
        case "slgt": self = .slight
        case "enh":  self = .enhanced
        case "mdt":  self = .moderate
        case "high": self = .high
        default: self = .allClear
        }
    }
    
    
    /// Returns the color gradient for use with the provided risk level
    /// - Parameter colorScheme: light or dark mode
    /// - Returns: a linear gradient to apply to the ui
    func iconColor(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        switch self {
        case .allClear, .thunderstorm:
            colors = colorScheme == .dark
            ? [.green.opacity(0.4), .green.darken()]
            : [.green.opacity(0.2), .green]
        case .marginal:
            colors = colorScheme == .dark
            ? [Color(hue: 0.33, saturation: 0.3, brightness: 0.5), .green.darken()]
            : [Color(hue: 0.33, saturation: 0.5, brightness: 0.8), .green]
        case .slight:
            colors = colorScheme == .dark
            ? [Color(hue: 0.15, saturation: 0.5, brightness: 0.6), .yellow.darken()]
            : [Color.yellow.opacity(0.3), .yellow]
        case .enhanced:
            colors = colorScheme == .dark
            ? [.orange.opacity(0.6), .orange.darken()]
            : [.orange.opacity(0.4), .orange]
        case .moderate:
            colors = colorScheme == .dark
            ? [.red.opacity(0.6), .red.darken()]
            : [.red.opacity(0.5), .red]
        case .high:
            colors = colorScheme == .dark
            ? [.purple.opacity(0.6), .purple.darken()]
            : [.purple.opacity(0.5), .purple]
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
