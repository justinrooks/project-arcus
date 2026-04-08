//
//  ext+Color.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension Color {
    // MARK: - Storm Risk Base Colors
    static let riskAllClear      = Color(red: 0.40, green: 0.75, blue: 0.40)
    static let riskThunderstorm  = Color(red: 0.35, green: 0.70, blue: 0.35)
    
    static let riskMarginal      = Color(red: 0.25, green: 0.60, blue: 0.30)
    
    static let riskSlight        = Color(red: 0.95, green: 0.80, blue: 0.25)
    static let riskEnhanced      = Color(red: 0.95, green: 0.55, blue: 0.20)
    
    static let riskModerate      = Color(red: 0.88, green: 0.30, blue: 0.25)
    static let riskHigh          = Color(red: 0.62, green: 0.25, blue: 0.80)
    
    // MARK: - Severe threat base colors
    static let tornadoRed        = Color(red: 0.8, green: 0.2, blue: 0.4)
    static let hailBlue          = Color(red: 0.3, green: 0.6, blue: 0.9)
    static let windTeal          = Color(red: 0.2, green: 0.7, blue: 0.7)
    
    static let severeTstormWarn  = Color(red: 0.38, green: 0.48, blue: 0.92)
        
    static let mesoPurple        = Color(red: 0.45, green: 0.35, blue: 0.85)
    
    static let fireWeather       = Color(red: 0.80, green: 0.36, blue: 0.16) // ~#CC5C29
    
    func tileGradient(for scheme: ColorScheme) -> LinearGradient {
        let top: Color
        let bottom: Color

        switch scheme {
        case .dark:
            // Dark mode: richer, deeper, more saturated
            top = self.opacity(0.85)
            bottom = self.darken()
        default:
            // Light mode: soft, clean, bright
            top = self.opacity(0.45)
            bottom = self
        }

        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func darken(by amount: Double = 0.2) -> Color {
        return self.opacity(1.0 - amount)
    }
}
