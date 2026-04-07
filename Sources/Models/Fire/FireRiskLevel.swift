//
//  FireRiskLevel.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/17/26.
//

import Foundation
import SwiftUI

enum FireRiskLevel: Int, CaseIterable, Identifiable, Comparable, Codable {
    case clear = 0
    case elevated = 5
    case critical = 8
    case extreme = 10

    var id: Self { self }
    
    static func < (lhs: FireRiskLevel, rhs: FireRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var status: String {
        switch self {
        case .clear: return "Clear"
        case .elevated: return "Elevated"
        case .critical: return "Critical"
        case .extreme: return "Extreme"
        }
    }

    var message: String {
        switch self {
        case .clear: return "No elevated fire weather risk from wind and low humidity is forecast."
        case .elevated: return "Elevated fire weather concerns. Wind and dry air may support faster fire spread if a fire starts."
        case .critical: return "Critical fire weather is forecast. Strong winds and dry air could support rapid fire spread."
        case .extreme: return "Extremely critical fire weather is forecast. Very strong wind and very dry air could support dangerous, fast-moving fire spread."
        }
    }

    var symbol: String {
        switch self {
        case .clear: return "checkmark.seal.fill"
        case .elevated: return "flame"
        case .critical: return "flame.fill"
        case .extreme: return "flame.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .clear: return Color(red: 0.87, green: 0.60, blue: 0.29)
        case .elevated: return .orange
        case .critical: return .red
        case .extreme: return .pink
        }
    }
    
    /// Returns the color gradient for use with the provided risk level
    /// - Parameter colorScheme: light or dark mode
    /// - Returns: a linear gradient to apply to the ui
    func iconColor(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .clear: return Color.riskAllClear.tileGradient(for: colorScheme)
        case .elevated: return Color.orange.tileGradient(for: colorScheme)
        case .critical: return Color.red.tileGradient(for: colorScheme)
        case .extreme:return Color.pink.tileGradient(for: colorScheme)
        }
    }
}
