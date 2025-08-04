//
//  MapCoordinator.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/3/25.
//

import MapKit
import Foundation

final class MapCoordinator: NSObject, MKMapViewDelegate {
    func parseRiskLabel(_ label: String) -> (type: String, percentage: String)? {
        let lowercase = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Handle patterns like: "10% Significant Hail Risk"
        let regex = try! NSRegularExpression(pattern: #"(\d+%)\s+(significant\s+)?(\w+)\s+risk"#, options: [.caseInsensitive])

        let nsLabel = label as NSString
        let range = NSRange(label.startIndex..., in: label)

        if let match = regex.firstMatch(in: label, range: range) {
            let percent = match.range(at: 1).location != NSNotFound ? nsLabel.substring(with: match.range(at: 1)) : "0%"
            let sigTag = match.range(at: 2).location != NSNotFound ? "significant " : ""
            let type = match.range(at: 3).location != NSNotFound ? nsLabel.substring(with: match.range(at: 3)).lowercased() : "unknown"
            
            return (type: (sigTag + type).trimmingCharacters(in: .whitespaces), percentage: percent)
        }

        // 2. Handle non-numeric structured labels
        let keywords: [String: String] = [
            "general thunderstorms": "tstm",
            "marginal": "mrgl",
            "slight": "slgt",
            "enhanced": "enh",
            "moderate": "mdt",
            "high": "high"
        ]

        for (key, value) in keywords {
            if lowercase.contains(key) {
                return (type: value, percentage: "0%")
            }
        }

        return nil
    }
    
    func getPolygonStyle(risk: String, probability: String) -> (UIColor, UIColor) {
        switch risk {
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
    
    func darken(_ color: UIColor, by probability: String) -> UIColor {
        let percent = Int(probability.replacingOccurrences(of: "%", with: "")) ?? 0
        let scale = min(max(CGFloat(percent) / 100.0, 0.0), 1.0)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Reduce brightness proportionally to risk
        let adjustedBrightness = max(brightness * (1.0 - 0.2 * scale), 0.1)

        return UIColor(hue: hue, saturation: saturation, brightness: adjustedBrightness, alpha: alpha)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.lineWidth = 1

            if let polygonTitle = polygon.title {
                let (risk, probability) = parseRiskLabel(polygonTitle) ?? ("unknown", "0%")
                let (fill, stroke) = getPolygonStyle(risk: risk.uppercased(), probability: probability)
                
                renderer.strokeColor = stroke
                renderer.fillColor = fill
            }

            return renderer
        }
        return MKOverlayRenderer()
    }
}
