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
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.lineWidth = 1

            if let polygonTitle = polygon.title {
                let (risk, probability) = parseRiskLabel(polygonTitle) ?? ("unknown", "0%")
                let (fill, stroke) = PolygonStyleProvider.getPolygonStyle(
                    risk: risk.uppercased(),
                    probability: probability
                )
                
                renderer.strokeColor = stroke
                renderer.fillColor = fill
            }

            return renderer
        }
        return MKOverlayRenderer()
    }
}
