import CoreLocation
import CoreGraphics
import MapKit

struct MapAccessibilitySummary: Equatable {
    let label: String
    let value: String

    static func make(
        scene: MapLayerScene,
        locationCoordinate: CLLocationCoordinate2D?,
        showsWarningGeometry: Bool
    ) -> MapAccessibilitySummary {
        let parts = [
            scene.legendState.voiceOverText,
            relationshipText(for: scene, locationCoordinate: locationCoordinate),
            warningOverlayText(for: scene, showsWarningGeometry: showsWarningGeometry)
        ]

        return MapAccessibilitySummary(
            label: "Map summary",
            value: parts.compactMap(\.self).joined(separator: " ")
        )
    }

    private static func relationshipText(
        for scene: MapLayerScene,
        locationCoordinate: CLLocationCoordinate2D?
    ) -> String? {
        guard scene.legendState.presentationState != .confirmedEmpty else { return nil }
        guard let locationCoordinate else { return "Local relationship unavailable." }

        let thematicPolygons = scene.canvasState.overlays.compactMap { entry in
            (entry.overlay as? RiskPolygonOverlay)?.polygon
        }

        guard thematicPolygons.isEmpty == false else { return "Local relationship unknown." }

        let isInsideDisplayedRisk = thematicPolygons.contains {
            PolygonHelpers.inPoly(user: locationCoordinate, polygon: $0)
        }

        let target = scene.legendState.layer.relationshipTarget
        if isInsideDisplayedRisk {
            return "Your location is inside the displayed \(target)."
        }

        return "Your location is outside the displayed \(target)."
    }

    private static func warningOverlayText(
        for scene: MapLayerScene,
        showsWarningGeometry: Bool
    ) -> String {
        guard showsWarningGeometry else {
            return "Active warnings overlay hidden."
        }

        let warningItems = WarningLegendItem.rendered(from: scene.canvasState.overlays)
        guard warningItems.isEmpty == false else {
            return "Active warnings overlay on. No active warning areas are displayed."
        }

        let renderedWarnings = warningItems.map {
            $0.accessibilityLabel.lowercased()
        }

        return "Active warnings overlay on. Displaying \(joinedList(renderedWarnings)) overlays."
    }

    private static func joinedList(_ phrases: [String]) -> String {
        switch phrases.count {
        case 0:
            return ""
        case 1:
            return phrases[0]
        case 2:
            return "\(phrases[0]) and \(phrases[1])"
        default:
            let head = phrases.dropLast().joined(separator: ", ")
            return "\(head), and \(phrases.last!)"
        }
    }
}

enum MapOverlayDifferentiationStyle: Equatable {
    case solid
    case dotted
    case shortDash
    case longDash
    case dashDot
    case emphasis

    static let mesoscale: MapOverlayDifferentiationStyle = .shortDash

    static func categorical(_ risk: StormRiskLevel) -> MapOverlayDifferentiationStyle {
        switch risk {
        case .allClear, .thunderstorm:
            return .solid
        case .marginal:
            return .dotted
        case .slight:
            return .shortDash
        case .enhanced:
            return .longDash
        case .moderate:
            return .dashDot
        case .high:
            return .emphasis
        }
    }

    static func severe(probability: ThreatProbability) -> MapOverlayDifferentiationStyle {
        switch probability {
        case .significant:
            return .emphasis
        case .percent(let value):
            switch Int((value * 100).rounded()) {
            case ...5:
                return .dotted
            case 6...10:
                return .shortDash
            case 11...15:
                return .longDash
            case 16...30:
                return .dashDot
            default:
                return .emphasis
            }
        }
    }

    static func fire(riskLevel: Int) -> MapOverlayDifferentiationStyle {
        switch riskLevel {
        case 10...:
            return .emphasis
        case 8...9:
            return .dashDot
        case 5...7:
            return .longDash
        default:
            return .shortDash
        }
    }

    static func overlayStyle(for overlayKey: String, kind: RiskPolygonKind) -> MapOverlayDifferentiationStyle? {
        guard case .probability = kind else { return nil }

        let components = overlayKey.split(separator: "|")
        guard let prefix = components.first else { return nil }

        switch prefix {
        case "cat":
            guard components.count > 1,
                  let rawValue = Int(components[1]),
                  let risk = StormRiskLevel(rawValue: rawValue) else {
                return nil
            }
            return categorical(risk)

        case "sev":
            guard components.count > 2 else { return nil }
            let token = String(components[2])
            if token.hasPrefix("sig"),
               let value = Int(token.dropFirst(3)) {
                return severe(probability: .significant(value))
            }
            if token.hasPrefix("p"),
               let value = Double(token.dropFirst()) {
                return severe(probability: .percent(value / 100.0))
            }
            return nil

        case "fire":
            guard components.count > 1,
                  let riskLevel = Int(components[1]) else {
                return nil
            }
            return fire(riskLevel: riskLevel)

        case "meso":
            return mesoscale

        default:
            return nil
        }
    }

    func strokeStyle(differentiateWithoutColor: Bool) -> MapOverlayStrokeStyle? {
        guard differentiateWithoutColor else { return nil }

        switch self {
        case .solid:
            return MapOverlayStrokeStyle(dashPattern: [], lineWidthMultiplier: 1.15)
        case .dotted:
            return MapOverlayStrokeStyle(dashPattern: [2, 3], lineWidthMultiplier: 1.1)
        case .shortDash:
            return MapOverlayStrokeStyle(dashPattern: [6, 4], lineWidthMultiplier: 1.15)
        case .longDash:
            return MapOverlayStrokeStyle(dashPattern: [10, 4], lineWidthMultiplier: 1.2)
        case .dashDot:
            return MapOverlayStrokeStyle(dashPattern: [10, 4, 2, 4], lineWidthMultiplier: 1.2)
        case .emphasis:
            return MapOverlayStrokeStyle(dashPattern: [14, 4], lineWidthMultiplier: 1.3)
        }
    }
}

struct MapOverlayStrokeStyle: Equatable {
    let dashPattern: [CGFloat]
    let lineWidthMultiplier: CGFloat
}

private extension MapLayer {
    var relationshipTarget: String {
        switch self {
        case .categorical:
            return "severe risk area"
        case .wind:
            return "wind risk area"
        case .hail:
            return "hail risk area"
        case .tornado:
            return "tornado risk area"
        case .meso:
            return "mesoscale area"
        case .fire:
            return "fire risk area"
        }
    }
}

extension MapLayer {
    var accessibilityLegendTitle: String {
        switch self {
        case .categorical:
            return "Severe Risk"
        case .wind:
            return "Wind Risk"
        case .hail:
            return "Hail Risk"
        case .tornado:
            return "Tornado Risk"
        case .meso:
            return "Mesoscale"
        case .fire:
            return "Fire Risk"
        }
    }
}

extension ThreatProbability {
    var accessibilityDescription: String {
        switch self {
        case .percent(let value):
            return "\(Int((value * 100).rounded())) percent probability"
        case .significant(let value):
            return "\(value) percent significant probability"
        }
    }
}
