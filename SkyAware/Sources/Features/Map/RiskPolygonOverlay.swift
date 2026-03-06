//
//  RiskPolygonOverlay.swift
//  SkyAware
//
//  Created by Codex on 3/5/26.
//

import Foundation
import MapKit
import UIKit

enum RiskPolygonKind: Hashable, Sendable {
    case probability
    case intensity(level: Int)
}

final class RiskPolygonOverlay: NSObject, MKOverlay {
    let polygon: MKPolygon
    let kind: RiskPolygonKind
    let strokeColor: UIColor
    let fillColor: UIColor
    let hatchStyle: HatchStyle?

    var coordinate: CLLocationCoordinate2D { polygon.coordinate }
    var boundingMapRect: MKMapRect { polygon.boundingMapRect }

    init(
        polygon: MKPolygon,
        kind: RiskPolygonKind,
        strokeColor: UIColor,
        fillColor: UIColor,
        hatchStyle: HatchStyle? = nil
    ) {
        self.polygon = polygon
        self.kind = kind
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.hatchStyle = hatchStyle
        super.init()
    }

    static func probability(from polygon: MKPolygon) -> RiskPolygonOverlay {
        let style = RiskPolygonStyleResolver.probabilityStyle(for: polygon)
        return RiskPolygonOverlay(
            polygon: polygon,
            kind: .probability,
            strokeColor: style.stroke,
            fillColor: style.fill
        )
    }

    static func intensity(
        from polygon: MKPolygon,
        level: Int,
        strokeColor: UIColor,
        fillColor: UIColor,
        hatchStyle: HatchStyle = .default
    ) -> RiskPolygonOverlay {
        RiskPolygonOverlay(
            polygon: polygon,
            kind: .intensity(level: level),
            strokeColor: strokeColor,
            fillColor: fillColor,
            hatchStyle: hatchStyle.adjusted(forIntensityLevel: level)
        )
    }
}

enum RiskPolygonStyleResolver {
    static func probabilityStyle(for polygon: MKPolygon) -> (fill: UIColor, stroke: UIColor) {
        let polygonTitle = polygon.title ?? ""
        let (risk, probability) = parseRiskLabel(polygonTitle) ?? ("unknown", "0%")
        let styleMetadata = StormRiskPolygonStyleMetadata.decode(from: polygon.subtitle)
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyle(
            risk: risk.uppercased(),
            probability: probability,
            spcFillHex: styleMetadata?.fillHex,
            spcStrokeHex: styleMetadata?.strokeHex
        )
        return (fill, stroke)
    }

    static func parseRiskLabel(_ label: String) -> (type: String, percentage: String)? {
        let lowercase = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let regex = try? NSRegularExpression(
            pattern: #"(\d+%)\s+(significant\s+)?(\w+)\s+risk"#,
            options: [.caseInsensitive]
        )

        let nsLabel = label as NSString
        let range = NSRange(label.startIndex..., in: label)

        if let regex,
           let match = regex.firstMatch(in: label, range: range) {
            let percent = match.range(at: 1).location != NSNotFound ? nsLabel.substring(with: match.range(at: 1)) : "0%"
            let sigTag = match.range(at: 2).location != NSNotFound ? "significant " : ""
            let type = match.range(at: 3).location != NSNotFound ? nsLabel.substring(with: match.range(at: 3)).lowercased() : "unknown"
            return (type: (sigTag + type).trimmingCharacters(in: .whitespaces), percentage: percent)
        }

        let keywords: [String: String] = [
            "general thunderstorms": "tstm",
            "marginal": "mrgl",
            "slight": "slgt",
            "enhanced": "enh",
            "moderate": "mdt",
            "high": "high",
            "meso": "meso",
            "fire": "fire"
        ]

        for (key, value) in keywords where lowercase.contains(key) {
            return (type: value, percentage: "0%")
        }

        return nil
    }
}
