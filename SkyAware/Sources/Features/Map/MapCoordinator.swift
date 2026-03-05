//
//  MapCoordinator.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/3/25.
//

import MapKit
import Foundation

final class MapCoordinator: NSObject, MKMapViewDelegate {
    var lastCenteredCoordinate: CLLocationCoordinate2D?

    init(lastCenteredCoordinate: CLLocationCoordinate2D? = nil) {
        self.lastCenteredCoordinate = lastCenteredCoordinate
    }

    func makeProbabilityOverlay(from polygon: MKPolygon) -> RiskPolygonOverlay {
        RiskPolygonOverlay.probability(from: polygon)
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
