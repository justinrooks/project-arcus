//
//  CONUSView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct CONUSMapView: UIViewRepresentable {
    let polygonList: MKMultiPolygon
    let coordinates: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = true

        
        // Initial viewport: if we have a user coordinate, center on it; otherwise fit all polygons
        if let coord = coordinates {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1_450_000, longitudinalMeters: 1_450_000)
            mapView.setRegion(region, animated: false)
        }
        
        
        
        
        
//        // Zoom the map to show the entire US
//        let center = coordinates ?? CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6) // fallback: center of CONUS
////        let region = MKCoordinateRegion(center: center, latitudinalMeters: 5000000, longitudinalMeters: 5000000) // Entire US
//        let region = MKCoordinateRegion(center: center, latitudinalMeters: 1450000, longitudinalMeters: 1450000)
//        mapView.setRegion(region, animated: false)

        // Add boundary overlays
//        let annotation = MKPointAnnotation()
//        annotation.coordinate = center // Use the calculated center coordinate
//        annotation.title = "Your Polygon Name" // Set the text you want to display

        mapView.addOverlays(polygonList.polygons)
//        mapView.addAnnotation(annotation)
        
        return mapView
    }

//    func updateUIView(_ uiView: MKMapView, context: Context) {
//        // Remove existing overlays
//        uiView.removeOverlays(uiView.overlays)
//
//        // Add new overlays from the updated polygonList
//        uiView.addOverlays(polygonList.polygons)
//    }
    func updateUIView(_ uiView: MKMapView, context: Context) {
        let existing = Set(uiView.overlays.compactMap { $0 as? MKPolygon })
        let incoming = Set(polygonList.polygons)

        let toRemove = existing.subtracting(incoming)
        let toAdd = incoming.subtracting(existing)

        if !toRemove.isEmpty { uiView.removeOverlays(Array(toRemove)) }
        if !toAdd.isEmpty { uiView.addOverlays(Array(toAdd)) }
        
        if let coord = coordinates {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1_450_000, longitudinalMeters: 1_450_000)
            uiView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }
}
