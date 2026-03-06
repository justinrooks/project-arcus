//
//  RiskPolygonOverlayTests.swift
//  SkyAwareTests
//
//  Created by Codex on 3/5/26.
//

import Foundation
import MapKit
import Testing
import UIKit
@testable import SkyAware

@Suite("RiskPolygonOverlay")
struct RiskPolygonOverlayTests {
    @Test("Hatch style spacing adjusts by intensity level")
    func hatchStyle_spacingAdjustsByLevel() {
        let base = HatchStyle.default
        #expect(abs(base.adjusted(forIntensityLevel: 1).spacing - (base.spacing * 1.10)) < 0.001)
        #expect(abs(base.adjusted(forIntensityLevel: 2).spacing - base.spacing) < 0.001)
        #expect(abs(base.adjusted(forIntensityLevel: 3).spacing - (base.spacing * 0.82)) < 0.001)
    }

    @Test("Hatch style pattern recipes are unique by intensity level")
    func hatchStyle_patternRecipesAreUniqueByLevel() {
        let base = HatchStyle.default
        let level1 = base.adjusted(forIntensityLevel: 1)
        let level2 = base.adjusted(forIntensityLevel: 2)
        let level3 = base.adjusted(forIntensityLevel: 3)

        #expect(level1.dashPattern != level2.dashPattern)
        #expect(level2.dashPattern != level3.dashPattern)
        #expect(level1.dashPattern != level3.dashPattern)
        #expect(level1.lineOffset != level2.lineOffset)
        #expect(level2.lineOffset != level3.lineOffset)
    }

    @Test("Probability overlay uses SPC style metadata colors")
    func probabilityOverlay_usesSpcMetadata() {
        let polygon = makePolygon()
        polygon.title = "10% Tornado Risk"
        polygon.subtitle = StormRiskPolygonStyleMetadata(
            fillHex: "#2255AA",
            strokeHex: "#AA5522"
        ).encoded

        let overlay = RiskPolygonOverlay.probability(from: polygon)

        let fill = rgba(overlay.fillColor)
        let stroke = rgba(overlay.strokeColor)

        #expect(abs(fill.red - 0.1333) < 0.01)
        #expect(abs(fill.green - 0.3333) < 0.01)
        #expect(abs(fill.blue - 0.6666) < 0.01)
        #expect(abs(fill.alpha - 0.3) < 0.01)

        #expect(abs(stroke.red - 0.6666) < 0.01)
        #expect(abs(stroke.green - 0.3333) < 0.01)
        #expect(abs(stroke.blue - 0.1333) < 0.01)
        #expect(abs(stroke.alpha - 1.0) < 0.01)
    }

    @Test("Intensity overlay stores level and adjusted hatch recipe")
    func intensityOverlay_storesLevelAndAdjustedStyle() {
        let polygon = makePolygon()
        let overlay = RiskPolygonOverlay.intensity(
            from: polygon,
            level: 3,
            strokeColor: .systemRed,
            fillColor: .systemRed
        )

        guard case .intensity(let level) = overlay.kind else {
            Issue.record("Expected intensity kind")
            return
        }

        #expect(level == 3)
        #expect(abs((overlay.hatchStyle?.spacing ?? 0) - (HatchStyle.default.spacing * 0.82)) < 0.001)
    }

    @MainActor
    @Test("MapCoordinator reuses cached overlay when geometry and style are unchanged")
    func mapCoordinator_reusesEquivalentOverlayForSameKey() {
        let coordinator = MapCoordinator()
        let key = "sev|tornado|p10|foo|0|0|probability"

        let first = RiskPolygonOverlay.probability(from: makeStyledPolygon())
        _ = coordinator.resolvedOverlay(for: key, incomingOverlay: first)

        let equivalent = RiskPolygonOverlay.probability(from: makeStyledPolygon())
        _ = coordinator.resolvedOverlay(for: key, incomingOverlay: equivalent)

        #expect(coordinator.key(for: first) == key)
        #expect(coordinator.key(for: equivalent) == nil)
    }

    @MainActor
    @Test("MapCoordinator replaces cached overlay when geometry changes under same key")
    func mapCoordinator_replacesOverlayWhenGeometryChangesForSameKey() {
        let coordinator = MapCoordinator()
        let key = "sev|tornado|p10|foo|0|0|probability"

        let first = RiskPolygonOverlay.probability(from: makeStyledPolygon())
        _ = coordinator.resolvedOverlay(for: key, incomingOverlay: first)

        let changedGeometry = RiskPolygonOverlay.probability(from: makeStyledPolygon(latitudeOffset: 0.5))
        _ = coordinator.resolvedOverlay(for: key, incomingOverlay: changedGeometry)

        #expect(coordinator.key(for: first) == nil)
        #expect(coordinator.key(for: changedGeometry) == key)
    }

    @MainActor
    @Test("MapCoordinator replaces cached overlay when style changes under same key")
    func mapCoordinator_replacesOverlayWhenStyleChangesForSameKey() {
        let coordinator = MapCoordinator()
        let key = "sev|tornado|p10|foo|0|0|probability"

        let first = RiskPolygonOverlay.probability(
            from: makeStyledPolygon(
                fillHex: "#2255AA",
                strokeHex: "#AA5522"
            )
        )
        _ = coordinator.resolvedOverlay(for: key, incomingOverlay: first)

        let changedStyle = RiskPolygonOverlay.probability(
            from: makeStyledPolygon(
                fillHex: "#44AA22",
                strokeHex: "#2266AA"
            )
        )
        _ = coordinator.resolvedOverlay(for: key, incomingOverlay: changedStyle)

        #expect(coordinator.key(for: first) == nil)
        #expect(coordinator.key(for: changedStyle) == key)
    }

    private func makePolygon() -> MKPolygon {
        var coordinates = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
            CLLocationCoordinate2D(latitude: 35.1, longitude: -96.9),
            CLLocationCoordinate2D(latitude: 35.2, longitude: -97.1)
        ]
        return MKPolygon(coordinates: &coordinates, count: coordinates.count)
    }

    private func makeStyledPolygon(
        latitudeOffset: CLLocationDegrees = 0,
        fillHex: String = "#2255AA",
        strokeHex: String = "#AA5522"
    ) -> MKPolygon {
        var coordinates = [
            CLLocationCoordinate2D(latitude: 35.0 + latitudeOffset, longitude: -97.0),
            CLLocationCoordinate2D(latitude: 35.1 + latitudeOffset, longitude: -96.9),
            CLLocationCoordinate2D(latitude: 35.2 + latitudeOffset, longitude: -97.1)
        ]
        let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
        polygon.title = "10% Tornado Risk"
        polygon.subtitle = StormRiskPolygonStyleMetadata(
            fillHex: fillHex,
            strokeHex: strokeHex
        ).encoded
        return polygon
    }

    private func rgba(_ color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}
