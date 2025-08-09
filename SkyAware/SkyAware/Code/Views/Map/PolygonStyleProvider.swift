//
//  PolygonStyleProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/4/25.
//

import SwiftUI
import UIKit

enum PolygonStyleProvider {
    
    static func getPolygonStyle(risk: String, probability: String) -> (UIColor, UIColor) {
        switch risk.uppercased() {
        case let r where r.contains("MRGL"):
            return (UIColor(hue: 0.33, saturation: 0.5, brightness: 0.8, alpha: 0.3), .green)
        case let r where r.contains("SLGT"):
            return (UIColor.yellow.withAlphaComponent(0.3), .yellow)
        case let r where r.contains("ENH"):
            return (UIColor.orange.withAlphaComponent(0.4), .orange)
        case let r where r.contains("MDT"):
            return (UIColor.red.withAlphaComponent(0.5), .red)
        case let r where r.contains("HIGH"):
            return (UIColor.purple.withAlphaComponent(0.5), .purple)
        case let r where r.contains("MESO"):
            return (UIColor.blue.withAlphaComponent(0.3), .blue)
            
        case let r where r.contains("WIND"):
            let isSignificant = r.contains("SIGN")
            let base = UIColor.systemTeal
            let dark = darken(base, by: probability)
            return (dark.withAlphaComponent(0.3), isSignificant ? UIColor.darkGray : dark)
            
        case let r where r.contains("HAIL"):
            let isSignificant = r.contains("SIGN")
            let base = UIColor.systemCyan
            let dark = darken(base, by: probability)
            return (dark.withAlphaComponent(0.3), isSignificant ? UIColor.darkGray : dark)
            
        case let r where r.contains("TOR"):
            let isSignificant = r.contains("SIGN")
            let base = UIColor.systemRed
            let dark = darken(base, by: probability)
            return (dark.withAlphaComponent(0.5), isSignificant ? UIColor.darkGray : dark)
            
        case let r where r.contains("TSTM"):
            return (
                UIColor(red: 0.75, green: 0.93, blue: 0.75, alpha: 0.3),
                UIColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 1.0)
            )
        default:
            print("Unknown Polygon Title. Investigate!")
            return (UIColor.systemOrange, UIColor.systemOrange.withAlphaComponent(0.15))
        }
    }
    
    static func darken(_ color: UIColor, by probability: String) -> UIColor {
        let percent = Int(probability.replacingOccurrences(of: "%", with: "")) ?? 0
        let scale = min(max(CGFloat(percent) / 100.0, 0.0), 1.0)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let adjustedBrightness = max(brightness * (1.0 - 0.2 * scale), 0.1)

        return UIColor(hue: hue, saturation: saturation, brightness: adjustedBrightness, alpha: alpha)
    }
}
