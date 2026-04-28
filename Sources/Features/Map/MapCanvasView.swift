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
    let signature: Int
}

struct MapCanvasView: UIViewRepresentable {
    let state: MapCanvasState
    private let defaultViewportMeters: CLLocationDistance = 1_450_000//2_200_000
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = true

        // Initial viewport: center once when we first get a coordinate.
        if let coord = state.initialCenterCoordinate {
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: defaultViewportMeters,
                longitudinalMeters: defaultViewportMeters
            )
            mapView.setRegion(region, animated: false)
            context.coordinator.lastCenteredCoordinate = coord
        }

        if !state.overlays.isEmpty {
            for entry in state.overlays {
                context.coordinator.registerOverlay(entry.overlay, key: entry.key, signature: entry.signature)
            }
            mapView.addOverlays(state.overlays.map(\.overlay))
        }
        context.coordinator.lastAppliedOverlayRevision = state.overlayRevision
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        if context.coordinator.lastAppliedOverlayRevision != state.overlayRevision {
            syncOverlays(on: uiView, incoming: state.overlays, coordinator: context.coordinator)
            context.coordinator.lastAppliedOverlayRevision = state.overlayRevision
        }

        if context.coordinator.lastCenteredCoordinate == nil, let coord = state.initialCenterCoordinate {
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: defaultViewportMeters,
                longitudinalMeters: defaultViewportMeters
            )
            uiView.setRegion(region, animated: true)
            context.coordinator.lastCenteredCoordinate = coord
        }
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
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
            let overlay = coordinator.resolvedOverlay(
                for: entry.key,
                incomingOverlay: entry.overlay,
                signature: entry.signature
            )
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
