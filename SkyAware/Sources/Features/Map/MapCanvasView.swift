//
//  MapCanvasView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit
import UIKit

struct MapOverlayEntry {
    let key: String
    let overlay: MKOverlay
}

struct MapCanvasView: UIViewRepresentable {
    let polygons: MKMultiPolygon
    let overlays: [MapOverlayEntry]
    let coordinates: CLLocationCoordinate2D?

    init(
        polygons: MKMultiPolygon,
        overlays: [MapOverlayEntry] = [],
        coordinates: CLLocationCoordinate2D?
    ) {
        self.polygons = polygons
        self.overlays = overlays
        self.coordinates = coordinates
    }

    init(
        polygons: [MKPolygon],
        overlays: [MapOverlayEntry] = [],
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

        let incoming = resolvedIncomingOverlays(using: context.coordinator)
        for entry in incoming {
            context.coordinator.registerOverlay(entry.overlay, key: entry.key)
        }
        mapView.addOverlays(incoming.map(\.overlay))
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let incoming = resolvedIncomingOverlays(using: context.coordinator)
        syncOverlays(on: uiView, incoming: incoming, coordinator: context.coordinator)

        if context.coordinator.lastCenteredCoordinate == nil, let coord = coordinates {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1_450_000, longitudinalMeters: 1_450_000)
            uiView.setRegion(region, animated: true)
            context.coordinator.lastCenteredCoordinate = coord
        }
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    private func resolvedIncomingOverlays(using coordinator: MapCoordinator) -> [MapOverlayEntry] {
        if !overlays.isEmpty {
            return overlays
        }

        return polygons.polygons.enumerated().map { index, polygon in
            let key = fallbackKey(for: polygon, index: index)
            let overlay = coordinator.overlay(for: key) ?? coordinator.makeProbabilityOverlay(from: polygon)
            return MapOverlayEntry(key: key, overlay: overlay)
        }
    }

    private func fallbackKey(for polygon: MKPolygon, index: Int) -> String {
        let rect = polygon.boundingMapRect
        return [
            "fallback",
            String(index),
            String(polygon.pointCount),
            String(Int(rect.origin.x.rounded())),
            String(Int(rect.origin.y.rounded())),
            String(Int(rect.size.width.rounded())),
            String(Int(rect.size.height.rounded())),
            polygon.title ?? "",
            polygon.subtitle ?? ""
        ].joined(separator: "|")
    }

    private func syncOverlays(
        on mapView: MKMapView,
        incoming: [MapOverlayEntry],
        coordinator: MapCoordinator
    ) {
        if incoming.isEmpty {
            if !mapView.overlays.isEmpty {
                mapView.removeOverlays(mapView.overlays)
            }
            coordinator.pruneOverlayCache(keeping: [])
            return
        }

        let desiredKeys = incoming.map(\.key)
        let desiredKeySet = Set(desiredKeys)

        var desiredOverlays: [MKOverlay] = []
        desiredOverlays.reserveCapacity(incoming.count)

        for entry in incoming {
            let overlay = coordinator.resolvedOverlay(for: entry.key, incomingOverlay: entry.overlay)
            desiredOverlays.append(overlay)
        }

        let currentOverlays = mapView.overlays
        var toRemove: [MKOverlay] = []
        toRemove.reserveCapacity(currentOverlays.count)

        for overlay in currentOverlays {
            guard let key = coordinator.key(for: overlay), desiredKeySet.contains(key) else {
                toRemove.append(overlay)
                coordinator.unregisterOverlay(overlay)
                continue
            }
        }

        if !toRemove.isEmpty {
            mapView.removeOverlays(toRemove)
        }

        let currentKeys = Set(mapView.overlays.compactMap { coordinator.key(for: $0) })
        var toAdd: [MKOverlay] = []
        toAdd.reserveCapacity(incoming.count)

        for (index, key) in desiredKeys.enumerated() where !currentKeys.contains(key) {
            toAdd.append(desiredOverlays[index])
        }

        if !toAdd.isEmpty {
            mapView.addOverlays(toAdd)
        }

        let finalKeys = mapView.overlays.compactMap { coordinator.key(for: $0) }
        if finalKeys != desiredKeys {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(desiredOverlays)
        }

        coordinator.pruneOverlayCache(keeping: desiredKeySet)
    }
}
