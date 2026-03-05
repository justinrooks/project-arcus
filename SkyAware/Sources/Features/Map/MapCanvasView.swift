//
//  MapCanvasView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit
import UIKit

struct MapCanvasView: UIViewRepresentable {
    let polygons: MKMultiPolygon
    let overlays: [MKOverlay]
    let coordinates: CLLocationCoordinate2D?

    init(
        polygons: MKMultiPolygon,
        overlays: [MKOverlay] = [],
        coordinates: CLLocationCoordinate2D?
    ) {
        self.polygons = polygons
        self.overlays = overlays
        self.coordinates = coordinates
    }

    init(
        polygons: [MKPolygon],
        overlays: [MKOverlay] = [],
        coordinates: CLLocationCoordinate2D?
    ) {
        self.init(
            polygons: MKMultiPolygon(polygons),
            overlays: overlays,
            coordinates: coordinates
        )
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = true

        // Initial viewport: center once when we first get a coordinate.
        if let coord = coordinates {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1_450_000, longitudinalMeters: 1_450_000)
            mapView.setRegion(region, animated: false)
            context.coordinator.lastCenteredCoordinate = coord
        }

        mapView.addOverlays(resolvedIncomingOverlays(using: context.coordinator))
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let incoming = resolvedIncomingOverlays(using: context.coordinator)
        if !overlaysMatchByIdentity(existing: uiView.overlays, incoming: incoming) {
            syncOverlays(on: uiView, incoming: incoming)
        }

        if context.coordinator.lastCenteredCoordinate == nil, let coord = coordinates {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1_450_000, longitudinalMeters: 1_450_000)
            uiView.setRegion(region, animated: true)
            context.coordinator.lastCenteredCoordinate = coord
        }
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    private func resolvedIncomingOverlays(using coordinator: MapCoordinator) -> [MKOverlay] {
        if !overlays.isEmpty {
            return overlays
        }

        return polygons.polygons.map { coordinator.makeProbabilityOverlay(from: $0) }
    }

    private func overlaysMatchByIdentity(existing: [MKOverlay], incoming: [MKOverlay]) -> Bool {
        guard existing.count == incoming.count else { return false }

        for (existingOverlay, incomingOverlay) in zip(existing, incoming) {
            guard existingOverlay === incomingOverlay else { return false }
        }

        return true
    }

    private func syncOverlays(on mapView: MKMapView, incoming: [MKOverlay]) {
        var existingBuckets = bucketize(overlays: mapView.overlays)
        var toAdd: [MKOverlay] = []

        for overlay in incoming {
            let key = overlaySignature(overlay)
            if var bucket = existingBuckets[key], !bucket.isEmpty {
                _ = bucket.removeLast()
                existingBuckets[key] = bucket.isEmpty ? nil : bucket
            } else {
                toAdd.append(overlay)
            }
        }

        let toRemove = existingBuckets.values.flatMap { $0 }
        if !toRemove.isEmpty { mapView.removeOverlays(toRemove) }
        if !toAdd.isEmpty { mapView.addOverlays(toAdd) }
    }

    private func bucketize(overlays: [MKOverlay]) -> [Int: [MKOverlay]] {
        var buckets: [Int: [MKOverlay]] = [:]
        buckets.reserveCapacity(overlays.count)

        for overlay in overlays {
            let key = overlaySignature(overlay)
            buckets[key, default: []].append(overlay)
        }

        return buckets
    }

    private func overlaySignature(_ overlay: MKOverlay) -> Int {
        var hasher = Hasher()

        if let riskOverlay = overlay as? RiskPolygonOverlay {
            hasher.combine("risk")
            hasher.combine(polygonGeometrySignature(riskOverlay.polygon))
            switch riskOverlay.kind {
            case .probability:
                hasher.combine(0)
            case .intensity(let level):
                hasher.combine(1)
                hasher.combine(level)
            }

            hasher.combine(colorSignature(riskOverlay.fillColor))
            hasher.combine(colorSignature(riskOverlay.strokeColor))

            if let hatchStyle = riskOverlay.hatchStyle {
                hasher.combine(Int((hatchStyle.angleDegrees * 100).rounded()))
                hasher.combine(Int((hatchStyle.spacing * 100).rounded()))
                hasher.combine(Int((hatchStyle.lineWidth * 100).rounded()))
                hasher.combine(Int((hatchStyle.opacity * 1000).rounded()))
            } else {
                hasher.combine(-1)
            }
            return hasher.finalize()
        }

        if let polygon = overlay as? MKPolygon {
            hasher.combine("polygon")
            hasher.combine(polygonGeometrySignature(polygon))
            hasher.combine(polygon.title ?? "")
            hasher.combine(polygon.subtitle ?? "")
            return hasher.finalize()
        }

        hasher.combine("overlay")
        hasher.combine(Int((overlay.coordinate.latitude * 100_000).rounded()))
        hasher.combine(Int((overlay.coordinate.longitude * 100_000).rounded()))
        hasher.combine(Int((overlay.boundingMapRect.origin.x / 100).rounded()))
        hasher.combine(Int((overlay.boundingMapRect.origin.y / 100).rounded()))
        hasher.combine(Int((overlay.boundingMapRect.size.width / 100).rounded()))
        hasher.combine(Int((overlay.boundingMapRect.size.height / 100).rounded()))
        return hasher.finalize()
    }

    private func polygonGeometrySignature(_ polygon: MKPolygon) -> Int {
        var hasher = Hasher()
        hasher.combine(polygon.pointCount)

        var coordinates = [CLLocationCoordinate2D](
            repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            count: polygon.pointCount
        )
        polygon.getCoordinates(&coordinates, range: NSRange(location: 0, length: polygon.pointCount))

        for coordinate in coordinates {
            hasher.combine(Int((coordinate.latitude * 100_000).rounded()))
            hasher.combine(Int((coordinate.longitude * 100_000).rounded()))
        }

        if let interiorPolygons = polygon.interiorPolygons {
            hasher.combine(interiorPolygons.count)
            for interior in interiorPolygons {
                hasher.combine(interior.pointCount)

                var interiorCoordinates = [CLLocationCoordinate2D](
                    repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    count: interior.pointCount
                )
                interior.getCoordinates(
                    &interiorCoordinates,
                    range: NSRange(location: 0, length: interior.pointCount)
                )

                for coordinate in interiorCoordinates {
                    hasher.combine(Int((coordinate.latitude * 100_000).rounded()))
                    hasher.combine(Int((coordinate.longitude * 100_000).rounded()))
                }
            }
        } else {
            hasher.combine(0)
        }

        return hasher.finalize()
    }

    private func colorSignature(_ color: UIColor) -> Int {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return Int((color.cgColor.alpha * 1000).rounded())
        }

        var hasher = Hasher()
        hasher.combine(Int((red * 1000).rounded()))
        hasher.combine(Int((green * 1000).rounded()))
        hasher.combine(Int((blue * 1000).rounded()))
        hasher.combine(Int((alpha * 1000).rounded()))
        return hasher.finalize()
    }
}
