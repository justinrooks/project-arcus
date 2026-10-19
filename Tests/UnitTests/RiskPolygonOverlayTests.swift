//
//  RiskPolygonOverlayTests.swift
//  SkyAwareTests
//
//  Created by Codex on 3/5/26.
//

import Darwin
import Foundation
import MapKit
import Testing
import UIKit
@testable import SkyAware

@Suite("RiskPolygonOverlay")
struct RiskPolygonOverlayTests {
    @Test("Profile hatch drawing with controlled polygon and draw-region sizes")
    func hatchDrawingMeasurement() throws {
        var report: [String] = []
        for width in [100_000.0, 40_000_000.0] {
            for zoom in [0.0001, 0.004] {
                for angle in [-45.0, 30.0] {
                    let renderer = hatchRenderer(width: width, angle: angle)
                    let bounds = try #require(renderer.path).boundingBoxOfPath
                    for pixels in [256.0, 1024.0] {
                        let region = CGRect(x: bounds.midX - pixels / zoom / 2,
                            y: bounds.midY - pixels / zoom / 2, width: pixels / zoom, height: pixels / zoom)
                        let context = try hatchContext(region: region, zoom: zoom)
                        let mapRect = renderer.mapRect(for: region)
                        renderer.draw(mapRect, zoomScale: zoom, in: context) // Warm up.
                        var wall: [Double] = []
                        var cpu: [Double] = []
                        for _ in 0..<8 {
                            let start = DispatchTime.now().uptimeNanoseconds
                            let cpuStart = hatchCPUTime()
                            renderer.draw(mapRect, zoomScale: zoom, in: context)
                            context.flush()
                            cpu.append(hatchCPUTime() - cpuStart)
                            wall.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                        }
                        let spacing = 32.0 / zoom // Both zooms reach the existing spacing cap (level 2).
                        let expanded = bounds.insetBy(dx: -spacing, dy: -spacing)
                        let diagonal = hypot(expanded.width, expanded.height)
                        let offset = HatchStyle.default.adjusted(forIntensityLevel: 2).lineOffset * 3.5 / zoom
                        let count = Int(floor((2 * diagonal - offset) / spacing)) + 1
                        let selected = RiskPolygonRenderer.hatchLineRange(bounds: expanded, drawRect: region,
                            angle: angle * .pi / 180, spacing: spacing, padding: 2.8 / zoom, lineOffset: offset)
                        report.append("width=\(width) zoom=\(zoom) angle=\(angle) mapRect=\(mapRect) " +
                            "legacyLines=\(count) boundedLines=\(selected.count) " +
                            "wallMs=\(hatchStatistics(wall)) cpuMs=\(hatchStatistics(cpu))")
                    }
                }
            }
        }
        Attachment.record(report.joined(separator: "\n"), named: "HatchDrawingMeasurement.txt")
    }

    @Test("Bounded hatch stripes preserve full-region pixels at tile edges and polygon holes",
        arguments: [-45.0, 0.0, 30.0, 90.0].flatMap { angle in
            [1, 2, 3].map { (angle: angle, level: $0) }
        }, [0.000024, 0.000025, 0.00004, 0.0001, 0.004])
    func hatchTilesMatchFullRegion(style: (angle: Double, level: Int), zoom: Double) throws {
        // Enough screen area to exercise several stripes even at the visibility threshold.
        let renderer = hatchRenderer(width: 600 / zoom, angle: style.angle, hole: true, level: style.level)
        let bounds = try #require(renderer.path).boundingBoxOfPath
        for origin in [CGPoint(x: bounds.midX - 128 / zoom, y: bounds.midY - 64 / zoom),
                       CGPoint(x: bounds.midX, y: bounds.midY - 64 / zoom),
                       CGPoint(x: bounds.minX - 64 / zoom, y: bounds.minY - 64 / zoom)] {
            let region = CGRect(origin: origin, size: CGSize(width: 128 / zoom, height: 128 / zoom))
            let bounded = try hatchContext(region: region, zoom: zoom)
            let reference = try hatchContext(region: region, zoom: zoom)
            renderer.draw(renderer.mapRect(for: region), zoomScale: zoom, in: bounded)
            renderer.draw(renderer.mapRect(for: bounds.insetBy(dx: -bounds.width, dy: -bounds.height)),
                zoomScale: zoom, in: reference)
            let actual = try #require(bounded.data).assumingMemoryBound(to: UInt8.self)
            let expected = try #require(reference.data).assumingMemoryBound(to: UInt8.self)
            let differences = (0..<(bounded.bytesPerRow * bounded.height)).map {
                abs(Int(actual[$0]) - Int(expected[$0]))
            }
            // Core Graphics can round antialiased coverage differently when off-tile
            // subpaths are omitted. Bound this to one 8-bit channel value at every pixel.
            #expect((differences.max() ?? 0) <= 1)
        }
        // An interior tile must stay completely transparent, including its hatch strokes.
        let hole = CGRect(x: bounds.midX - 16 / zoom, y: bounds.midY - 16 / zoom,
            width: 32 / zoom, height: 32 / zoom)
        let context = try hatchContext(region: hole, zoom: zoom)
        renderer.draw(renderer.mapRect(for: hole), zoomScale: zoom, in: context)
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        #expect((0..<(context.bytesPerRow * context.height)).allSatisfy { bytes[$0] == 0 })
        let interior = CGRect(x: bounds.minX + 48 / zoom, y: bounds.minY + 48 / zoom,
            width: 64 / zoom, height: 64 / zoom)
        let visible = try hatchContext(region: interior, zoom: zoom)
        renderer.draw(renderer.mapRect(for: interior), zoomScale: zoom, in: visible)
        let visibleBytes = try #require(visible.data).assumingMemoryBound(to: UInt8.self)
        let hasHatching = (0..<(visible.bytesPerRow * visible.height)).contains { visibleBytes[$0] > 0 }
        #expect(hasHatching == (zoom >= RiskPolygonRenderer.hatchZoomThreshold))
    }

    @Test("Draw-region stripe selection bounds workload and retains every intersecting legacy stripe",
        arguments: [-90.0, -45.0, 0.0, 30.0, 135.0])
    func hatchLineSelection(angle: Double) {
        let bounds = CGRect(x: 91_000, y: -123_000, width: 40_000_000, height: 24_000_000)
        let region = CGRect(x: bounds.midX - 32_000, y: bounds.midY - 32_000, width: 64_000, height: 64_000)
        let radians = angle * .pi / 180
        let spacing = 8_000.0
        let offset = 4_528.125
        let lines = RiskPolygonRenderer.hatchLineRange(bounds: bounds, drawRect: region,
            angle: radians, spacing: spacing, padding: 700, lineOffset: offset)
        #expect(lines.count < 20)
        let projected = region.offsetBy(dx: -bounds.midX, dy: -bounds.midY)
            .applying(CGAffineTransform(rotationAngle: -radians))
        let diagonal = hypot(bounds.width, bounds.height)
        var y = -diagonal + offset
        var index = 0
        while y <= diagonal {
            if y >= projected.minY - 700, y <= projected.maxY + 700 {
                #expect(lines.contains(index))
                #expect(abs(y - (-diagonal + offset + Double(index) * spacing)) < 0.001)
            }
            index += 1
            y += spacing
        }
        #expect(RiskPolygonRenderer.hatchLineRange(bounds: bounds,
            drawRect: bounds.offsetBy(dx: bounds.width * 2, dy: 0), angle: radians,
            spacing: spacing, padding: 700, lineOffset: offset).isEmpty)
    }

    private func hatchRenderer(width: Double, angle: Double, hole: Bool = false, level: Int = 2) -> RiskPolygonRenderer {
        var points = [MKMapPoint(x: 80_000_000, y: 80_000_000),
            MKMapPoint(x: 80_000_000 + width, y: 80_000_000),
            MKMapPoint(x: 80_000_000 + width, y: 80_000_000 + width * 0.6),
            MKMapPoint(x: 80_000_000, y: 80_000_000 + width * 0.6)]
        var interiors: [MKPolygon] = []
        if hole {
            var ring = [MKMapPoint(x: 80_000_000 + width * 0.4, y: 80_000_000 + width * 0.2),
                MKMapPoint(x: 80_000_000 + width * 0.6, y: 80_000_000 + width * 0.2),
                MKMapPoint(x: 80_000_000 + width * 0.6, y: 80_000_000 + width * 0.4),
                MKMapPoint(x: 80_000_000 + width * 0.4, y: 80_000_000 + width * 0.4)]
            interiors = [MKPolygon(points: &ring, count: ring.count)]
        }
        let polygon = MKPolygon(points: &points, count: points.count, interiorPolygons: interiors)
        var style = HatchStyle.default
        style.angleDegrees = angle
        let renderer = RiskPolygonRenderer(riskOverlay: .intensity(from: polygon, level: level,
            strokeColor: .red, fillColor: .clear, hatchStyle: style), differentiateWithoutColor: false)
        renderer.createPath()
        return renderer
    }

    private func hatchContext(region: CGRect, zoom: Double) throws -> CGContext {
        let context = try #require(CGContext(data: nil, width: Int((region.width * zoom).rounded()),
            height: Int((region.height * zoom).rounded()), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.scaleBy(x: zoom, y: zoom)
        context.translateBy(x: -region.minX, y: -region.minY)
        context.clip(to: region)
        return context
    }

    private func hatchCPUTime() -> Double {
        var value = timespec()
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value)
        return Double(value.tv_sec) * 1_000 + Double(value.tv_nsec) / 1_000_000
    }

    private func hatchStatistics(_ values: [Double]) -> String {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return "median:\(values.sorted()[values.count / 2]),mean:\(mean),sd:\(sqrt(variance))"
    }

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

    @Test("Filled polygon paths exclude interior rings regardless of winding")
    func rendererPath_evenOddFillTreatsInteriorRingAsHole() throws {
        var exterior = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
            CLLocationCoordinate2D(latitude: 35.4, longitude: -97.0),
            CLLocationCoordinate2D(latitude: 35.0, longitude: -96.6)
        ]
        var hole = [
            CLLocationCoordinate2D(latitude: 35.08, longitude: -96.92),
            CLLocationCoordinate2D(latitude: 35.08, longitude: -96.80),
            CLLocationCoordinate2D(latitude: 35.20, longitude: -96.92)
        ]
        let interior = MKPolygon(coordinates: &hole, count: hole.count)
        let polygon = MKPolygon(
            coordinates: &exterior,
            count: exterior.count,
            interiorPolygons: [interior]
        )
        let overlay = RiskPolygonOverlay.probability(from: polygon)
        let renderer = RiskPolygonRenderer(riskOverlay: overlay, differentiateWithoutColor: false)
        renderer.createPath()
        let path = try #require(renderer.path)

        let holePoint = renderer.point(for: MKMapPoint(CLLocationCoordinate2D(latitude: 35.11, longitude: -96.88)))
        let filledPoint = renderer.point(for: MKMapPoint(CLLocationCoordinate2D(latitude: 35.02, longitude: -96.95)))

        #expect(path.contains(holePoint, using: .evenOdd) == false)
        #expect(path.contains(filledPoint, using: .evenOdd))
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

    @MainActor
    @Test("MapCoordinator renders warning polygons with warning-specific styling")
    func mapCoordinator_rendersWarningPolygonWithWarningStyle() {
        let coordinator = MapCoordinator()
        let polygon = makeWarningPolygon(title: "Severe Thunderstorm Warning")
        let expected = rgba(.warningYellow)

        let renderer = coordinator.mapView(MKMapView(), rendererFor: polygon)

        guard let polygonRenderer = renderer as? MKPolygonRenderer else {
            Issue.record("Expected MKPolygonRenderer")
            return
        }

        #expect(abs(polygonRenderer.lineWidth - 2) < 0.001)
        #expect(rgba(polygonRenderer.strokeColor ?? .clear) == expected)
        #expect(rgba(polygonRenderer.fillColor ?? .clear).red == expected.red)
        #expect(rgba(polygonRenderer.fillColor ?? .clear).green == expected.green)
        #expect(rgba(polygonRenderer.fillColor ?? .clear).blue == expected.blue)
        #expect(abs(rgba(polygonRenderer.fillColor ?? .clear).alpha - 0.22) < 0.001)
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

    private func makeWarningPolygon(title: String) -> MKPolygon {
        var coordinates = [
            CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
            CLLocationCoordinate2D(latitude: 35.1, longitude: -96.9),
            CLLocationCoordinate2D(latitude: 35.2, longitude: -97.1)
        ]
        let polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
        polygon.title = title
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
