//
//  PolygonStyleProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/4/25.
//

import SwiftUI
import UIKit

/// Where the color will be shown. Legend needs stronger contrast than map fills.
enum ColorContext { case map, legend }

enum PolygonStyleProvider {
    
    /// Returns the Fill and stroke based on the polygon title
    /// - Parameters:
    ///   - risk: the type of risk we are mapping for. Either MRGL, HAIL, etc
    ///   - probability: probability associated with severe threats (hail, tornado, wind)
    ///   - context: whether we are rendering this for the map or the legend since there are different sizes involved
    /// - Returns: a tuple with fill property first followed by stroke
    static func getPolygonStyle(risk: String, probability: String, context: ColorContext = .map) -> (UIColor, UIColor) {
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
            return (UIColor.systemIndigo.withAlphaComponent(0.3), .systemIndigo)
            
        case let r where r.contains("WIND"):
            let isSignificant = r.contains("SIGN")
            let base = parseHailWindProbability(probability)
            let alpha = context == .map ? 0.3 : 0.7
            return (base.withAlphaComponent(alpha), isSignificant ? UIColor.black : base)
            
        case let r where r.contains("HAIL"):
            let isSignificant = r.contains("SIGN")
            let base = parseHailWindProbability(probability)
            let alpha = context == .map ? 0.3 : 0.7
            return (base.withAlphaComponent(alpha), isSignificant ? UIColor.black : base)
            
        case let r where r.contains("TOR"):
            let isSignificant = r.contains("SIGN")
            let base = parseTorProbability(probability)
            let alpha = context == .map ? 0.3 : 0.7
            return (base.withAlphaComponent(alpha), isSignificant ? UIColor.black : base)
            
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
    
    static func getPolygonStyleForLegend(risk: String, probability: String) -> (UIColor, UIColor) {
        getPolygonStyle(risk: risk, probability: probability, context: .legend)
    }
    
    
    private static func parseHailWindProbability(_ probability: String) -> UIColor {
        let percent = Int(probability.replacingOccurrences(of: "%", with: "")) ?? 0
        switch percent {
        case 1..<6:
            return UIColor.systemBrown
        case 7..<16:
            return UIColor.systemYellow
        case 17..<31:
            return UIColor.systemRed
        case 32..<46:
            return UIColor.systemPink
        case 47..<61:
            return UIColor.systemPurple
        default:
            return UIColor.systemCyan
        }
    }
    
    private static func parseTorProbability(_ probability: String) -> UIColor {
        let percent = Int(probability.replacingOccurrences(of: "%", with: "")) ?? 0
        switch percent {
        case 1..<3:
            return UIColor.systemGreen
        case 4..<6:
            return UIColor.systemBrown
        case 7..<11:
            return UIColor.systemYellow
        case 12..<16:
            return UIColor.systemRed
        case 17..<31:
            return UIColor.systemPink
        case 32..<46:
            return UIColor.systemPurple
        case 47..<61:
            return UIColor.systemIndigo
        default:
            return UIColor.systemRed
        }
    }
}
