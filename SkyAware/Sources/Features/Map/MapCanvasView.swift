//
//  MapCanvasView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct MapCanvasView: UIViewRepresentable {
    let polygons: MKMultiPolygon
    let coordinates: CLLocationCoordinate2D?
    
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

        mapView.addOverlays(polygons.polygons)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let incoming = polygons.polygons
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

    private func overlaysMatchByIdentity(existing: [MKOverlay], incoming: [MKPolygon]) -> Bool {
        guard existing.count == incoming.count else { return false }

        for (overlay, polygon) in zip(existing, incoming) {
            guard let existingPolygon = overlay as? MKPolygon, existingPolygon === polygon else { return false }
        }

        return true
    }

    private func syncOverlays(on mapView: MKMapView, incoming: [MKPolygon]) {
        var existingBuckets = bucketize(polygons: mapView.overlays.compactMap { $0 as? MKPolygon })
        var toAdd: [MKPolygon] = []

        for polygon in incoming {
            let key = polygonSignature(polygon)
            if var bucket = existingBuckets[key], !bucket.isEmpty {
                _ = bucket.removeLast()
                existingBuckets[key] = bucket.isEmpty ? nil : bucket
            } else {
                toAdd.append(polygon)
            }
        }

        let toRemove = existingBuckets.values.flatMap { $0 }
        if !toRemove.isEmpty { mapView.removeOverlays(toRemove) }
        if !toAdd.isEmpty { mapView.addOverlays(toAdd) }
    }

    private func bucketize(polygons: [MKPolygon]) -> [Int: [MKPolygon]] {
        var buckets: [Int: [MKPolygon]] = [:]
        buckets.reserveCapacity(polygons.count)

        for polygon in polygons {
            let key = polygonSignature(polygon)
            buckets[key, default: []].append(polygon)
        }

        return buckets
    }

    private func polygonSignature(_ polygon: MKPolygon) -> Int {
        var hasher = Hasher()
        hasher.combine(polygon.title ?? "")
        hasher.combine(polygon.subtitle ?? "")
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

        return hasher.finalize()
    }
}
