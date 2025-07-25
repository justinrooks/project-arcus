//
//  StormRiskLevel.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/24/25.
//

import SwiftUI

enum StormRiskLevel: Int, CaseIterable, Identifiable, Comparable {
    case allClear = 0
    case marginal = 1
    case slight = 2
    case enhanced = 3
    case moderate = 4
    case high = 5
    
    var id: Self { self }
   
        static func < (lhs: StormRiskLevel, rhs: StormRiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

    var iconName: String {
        switch self {
        case .allClear: return "checkmark.seal"
        case .marginal: return "circle.dashed"
        case .slight: return "exclamationmark.triangle.fill"
        case .enhanced: return "bolt.fill"
        case .moderate: return "exclamationmark.octagon"
        case .high: return "flame"
        }
    }

    func iconColor(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        switch self {
        case .allClear:
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
    
    var message: String {
        switch self {
        case .allClear: return "All Clear"
        case .marginal: return "Marginal"
        case .slight: return "Slight Risk"
        case .enhanced: return "Enhanced Risk"
        case .moderate: return "Moderate Risk"
        case .high: return "High Risk"
        }
    }
    
    var summary: String {
        switch self {
        case .allClear: return "No severe storms expected"
        case .marginal: return "Low risk, but some stronger storms possible"
        case .slight: return "Chance for a few strong storms"
        case .enhanced: return "Several severe storms are possible"
        case .moderate: return "Widespread severe storms expected"
        case .high: return "Severe outbreak likely — stay alert"
        }
    }
}
