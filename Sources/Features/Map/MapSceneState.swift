//
//  MapSceneState.swift
//  SkyAware
//
//  Created by Codex on 7/13/26.
//

import CoreLocation

struct MapLayerScene {
    let canvasState: MapCanvasState
    let legendState: MapLegendState
    let warningLegendItems: [WarningLegendItem]

    static func placeholder(
        for layer: MapLayer,
        initialCenterCoordinate: CLLocationCoordinate2D? = nil
    ) -> MapLayerScene {
        MapLayerScene(
            canvasState: MapCanvasState(
                overlays: [],
                overlayRevision: 0,
                initialCenterCoordinate: initialCenterCoordinate
            ),
            legendState: .loading(for: layer),
            warningLegendItems: []
        )
    }

    func withInitialCenterCoordinateIfNeeded(_ coordinate: CLLocationCoordinate2D) -> MapLayerScene {
        guard canvasState.initialCenterCoordinate == nil else { return self }
        return MapLayerScene(
            canvasState: canvasState.withInitialCenterCoordinate(coordinate),
            legendState: legendState,
            warningLegendItems: warningLegendItems
        )
    }

    func withPresentationState(_ presentationState: MapLegendPresentationState) -> MapLayerScene {
        MapLayerScene(
            canvasState: canvasState,
            legendState: legendState.withPresentationState(presentationState),
            warningLegendItems: warningLegendItems
        )
    }
}

struct MapCanvasState {
    let overlays: [MapOverlayEntry]
    let overlayRevision: Int
    let initialCenterCoordinate: CLLocationCoordinate2D?

    func withInitialCenterCoordinate(_ coordinate: CLLocationCoordinate2D) -> MapCanvasState {
        MapCanvasState(
            overlays: overlays,
            overlayRevision: overlayRevision,
            initialCenterCoordinate: coordinate
        )
    }
}
