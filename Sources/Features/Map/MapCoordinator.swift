//
//  MapCoordinator.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/3/25.
//

import MapKit
import Foundation
import UIKit

@MainActor
final class MapCoordinator: NSObject, MKMapViewDelegate {
    var lastCenteredCoordinate: CLLocationCoordinate2D?
    var lastAppliedOverlayRevision: Int?
    private var overlayByKey: [String: MKOverlay] = [:]
    private var keyByOverlayIdentifier: [ObjectIdentifier: String] = [:]
    private var signatureByKey: [String: OverlaySignature] = [:]

    private struct OverlaySignature: Hashable {
        let fingerprint: Int
    }

    init(lastCenteredCoordinate: CLLocationCoordinate2D? = nil) {
        self.lastCenteredCoordinate = lastCenteredCoordinate
    }

    func makeProbabilityOverlay(from polygon: MKPolygon) -> RiskPolygonOverlay {
        RiskPolygonOverlay.probability(from: polygon)
    }

    func overlay(for key: String) -> MKOverlay? {
        overlayByKey[key]
    }

    func resolvedOverlay(for key: String, incomingOverlay: MKOverlay) -> MKOverlay {
        resolvedOverlay(
            for: key,
            incomingOverlay: incomingOverlay,
            signature: overlaySignature(for: incomingOverlay).fingerprint
        )
    }

    func resolvedOverlay(for key: String, incomingOverlay: MKOverlay, signature: Int) -> MKOverlay {
        let incomingSignature = OverlaySignature(fingerprint: signature)

        if let cachedOverlay = overlayByKey[key],
           signatureByKey[key] == incomingSignature {
            registerOverlay(cachedOverlay, key: key, signature: signature)
            return cachedOverlay
        }

        registerOverlay(incomingOverlay, key: key, signature: signature)
        return incomingOverlay
    }

    func registerOverlay(_ overlay: MKOverlay, key: String) {
        let incomingSignature = overlaySignature(for: overlay)
        registerOverlay(overlay, key: key, signature: incomingSignature.fingerprint)
    }

    func registerOverlay(_ overlay: MKOverlay, key: String, signature: Int) {
        if let previousOverlay = overlayByKey[key],
           (previousOverlay as AnyObject) !== (overlay as AnyObject) {
            let previousIdentifier = ObjectIdentifier(previousOverlay as AnyObject)
            keyByOverlayIdentifier.removeValue(forKey: previousIdentifier)
        }

        let identifier = ObjectIdentifier(overlay as AnyObject)
        overlayByKey[key] = overlay
        signatureByKey[key] = OverlaySignature(fingerprint: signature)
        keyByOverlayIdentifier[identifier] = key
    }

    func key(for overlay: MKOverlay) -> String? {
        let identifier = ObjectIdentifier(overlay as AnyObject)
        return keyByOverlayIdentifier[identifier]
    }

    func unregisterOverlay(_ overlay: MKOverlay) {
        let identifier = ObjectIdentifier(overlay as AnyObject)
        guard let key = keyByOverlayIdentifier.removeValue(forKey: identifier) else { return }
        if let cachedOverlay = overlayByKey[key],
           (cachedOverlay as AnyObject) === (overlay as AnyObject) {
            overlayByKey.removeValue(forKey: key)
            signatureByKey.removeValue(forKey: key)
        }
    }

    func pruneOverlayCache(keeping keys: Set<String>) {
        overlayByKey = overlayByKey.filter { keys.contains($0.key) }
        signatureByKey = signatureByKey.filter { keys.contains($0.key) }
        keyByOverlayIdentifier = keyByOverlayIdentifier.filter { keys.contains($0.value) }
        if keys.isEmpty {
            lastAppliedOverlayRevision = nil
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let riskOverlay = overlay as? RiskPolygonOverlay {
            return RiskPolygonRenderer(riskOverlay: riskOverlay)
        }

        if let polygon = overlay as? MKPolygon {
            if let warningStyle = warningPolygonStyle(for: polygon.title ?? "") {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.lineWidth = 2
                renderer.strokeColor = warningStyle.stroke
                renderer.fillColor = warningStyle.fill
                return renderer
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.lineWidth = 1
            let style = RiskPolygonStyleResolver.probabilityStyle(for: polygon)
            renderer.strokeColor = style.stroke
            renderer.fillColor = style.fill
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }

    private func overlaySignature(for overlay: MKOverlay) -> OverlaySignature {
        var hasher = Hasher()

        if let riskOverlay = overlay as? RiskPolygonOverlay {
            hasher.combine("risk")
            hasher.combine(riskOverlay.kind)
            appendPolygonSignature(riskOverlay.polygon, to: &hasher)
            appendColorSignature(riskOverlay.strokeColor, to: &hasher)
            appendColorSignature(riskOverlay.fillColor, to: &hasher)
            hasher.combine(riskOverlay.hatchStyle)
            return OverlaySignature(fingerprint: hasher.finalize())
        }

        if let polygon = overlay as? MKPolygon {
            hasher.combine("polygon")
            appendPolygonSignature(polygon, to: &hasher)
            return OverlaySignature(fingerprint: hasher.finalize())
        }

        hasher.combine(String(describing: type(of: overlay)))
        appendMapRect(overlay.boundingMapRect, to: &hasher)
        appendCoordinate(overlay.coordinate, to: &hasher)
        return OverlaySignature(fingerprint: hasher.finalize())
    }

    private func appendPolygonSignature(_ polygon: MKPolygon, to hasher: inout Hasher) {
        appendMapRect(polygon.boundingMapRect, to: &hasher)
        appendCoordinate(polygon.coordinate, to: &hasher)
        hasher.combine(polygon.title ?? "")
        hasher.combine(polygon.subtitle ?? "")

        appendRing(points: polygon.points(), count: polygon.pointCount, to: &hasher)

        let interiorPolygons = polygon.interiorPolygons ?? []
        hasher.combine(interiorPolygons.count)
        for interior in interiorPolygons {
            appendRing(points: interior.points(), count: interior.pointCount, to: &hasher)
        }
    }

    private func appendRing(
        points: UnsafeMutablePointer<MKMapPoint>,
        count: Int,
        to hasher: inout Hasher
    ) {
        hasher.combine(count)
        guard count > 0 else { return }

        for index in 0..<count {
            hasher.combine(quantizedMapValue(points[index].x))
            hasher.combine(quantizedMapValue(points[index].y))
        }
    }

    private func appendColorSignature(_ color: UIColor, to hasher: inout Hasher) {
        let lightTrait = UITraitCollection(userInterfaceStyle: .light)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)
        appendRGBAComponents(for: color.resolvedColor(with: lightTrait), to: &hasher)
        appendRGBAComponents(for: color.resolvedColor(with: darkTrait), to: &hasher)
    }

    private func appendRGBAComponents(for color: UIColor, to hasher: inout Hasher) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            hasher.combine(quantizedColorValue(red))
            hasher.combine(quantizedColorValue(green))
            hasher.combine(quantizedColorValue(blue))
            hasher.combine(quantizedColorValue(alpha))
            return
        }

        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil),
              let components = converted.components else {
            hasher.combine(0)
            hasher.combine(0)
            hasher.combine(0)
            hasher.combine(0)
            return
        }

        switch components.count {
        case 4:
            hasher.combine(quantizedColorValue(components[0]))
            hasher.combine(quantizedColorValue(components[1]))
            hasher.combine(quantizedColorValue(components[2]))
            hasher.combine(quantizedColorValue(components[3]))
        case 2:
            let grayscale = quantizedColorValue(components[0])
            hasher.combine(grayscale)
            hasher.combine(grayscale)
            hasher.combine(grayscale)
            hasher.combine(quantizedColorValue(components[1]))
        default:
            hasher.combine(0)
            hasher.combine(0)
            hasher.combine(0)
            hasher.combine(0)
        }
    }

    private func appendMapRect(_ rect: MKMapRect, to hasher: inout Hasher) {
        hasher.combine(quantizedMapValue(rect.origin.x))
        hasher.combine(quantizedMapValue(rect.origin.y))
        hasher.combine(quantizedMapValue(rect.size.width))
        hasher.combine(quantizedMapValue(rect.size.height))
    }

    private func appendCoordinate(_ coordinate: CLLocationCoordinate2D, to hasher: inout Hasher) {
        hasher.combine(quantizedCoordinateValue(coordinate.latitude))
        hasher.combine(quantizedCoordinateValue(coordinate.longitude))
    }

    private func quantizedMapValue(_ value: Double) -> Int {
        Int((value * 64.0).rounded())
    }

    private func quantizedCoordinateValue(_ value: CLLocationDegrees) -> Int {
        Int((value * 1_000_000.0).rounded())
    }

    private func quantizedColorValue(_ value: CGFloat) -> Int {
        let clamped = max(0, min(1, value))
        return Int((clamped * 10_000.0).rounded())
    }
}
