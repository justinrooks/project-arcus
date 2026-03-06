//
//  MapCoordinator.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/3/25.
//

import MapKit
import Foundation

@MainActor
final class MapCoordinator: NSObject, MKMapViewDelegate {
    var lastCenteredCoordinate: CLLocationCoordinate2D?
    private var overlayByKey: [String: MKOverlay] = [:]
    private var keyByOverlayIdentifier: [ObjectIdentifier: String] = [:]

    init(lastCenteredCoordinate: CLLocationCoordinate2D? = nil) {
        self.lastCenteredCoordinate = lastCenteredCoordinate
    }

    func makeProbabilityOverlay(from polygon: MKPolygon) -> RiskPolygonOverlay {
        RiskPolygonOverlay.probability(from: polygon)
    }

    func overlay(for key: String) -> MKOverlay? {
        overlayByKey[key]
    }

    func registerOverlay(_ overlay: MKOverlay, key: String) {
        let identifier = ObjectIdentifier(overlay as AnyObject)
        overlayByKey[key] = overlay
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
        }
    }

    func pruneOverlayCache(keeping keys: Set<String>) {
        overlayByKey = overlayByKey.filter { keys.contains($0.key) }
        keyByOverlayIdentifier = keyByOverlayIdentifier.filter { keys.contains($0.value) }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let riskOverlay = overlay as? RiskPolygonOverlay {
            return RiskPolygonRenderer(riskOverlay: riskOverlay)
        }

        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.lineWidth = 1
            let style = RiskPolygonStyleResolver.probabilityStyle(for: polygon)
            renderer.strokeColor = style.stroke
            renderer.fillColor = style.fill
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }
}
