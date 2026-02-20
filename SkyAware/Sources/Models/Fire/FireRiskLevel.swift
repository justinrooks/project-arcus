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
        case .clear: return "No concerning fire weather products."
        case .elevated: return "Conditions are above normal for wildfire spread. Wind and low humidity could increase fire potential."
        case .critical: return "Critical fire weather conditions expected. Strong winds and dry air could support rapid fire spread."
        case .extreme: return "Extremely critical fire weather forecast. Very strong winds, low humidity, and dry fuels may fuel rapid and intense wildfire spread."
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
