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
    @EnvironmentObject private var locationProvider: LocationManager

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = true

        // Zoom the map to show the entire US
        let center = locationProvider.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6) // fallback: center of CONUS
//        let region = MKCoordinateRegion(center: center, latitudinalMeters: 5000000, longitudinalMeters: 5000000) // Entire US
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 1450000, longitudinalMeters: 1450000)
        mapView.setRegion(region, animated: true)

        // Add boundary overlays
//        let annotation = MKPointAnnotation()
//        annotation.coordinate = center // Use the calculated center coordinate
//        annotation.title = "Your Polygon Name" // Set the text you want to display
//        
        mapView.addOverlay(polygonList)
//        mapView.addAnnotation(annotation)
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove existing overlays
        uiView.removeOverlays(uiView.overlays)

        // Add new overlays from the updated polygonList
        uiView.addOverlays(polygonList.polygons)
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }
}

//#Preview {
//    CONUSMapView()
//}
