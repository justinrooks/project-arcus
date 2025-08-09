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
    @Environment(LocationManager.self) private var locationProvider: LocationManager

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
        
        
//        let coords = MesoGeometry.coordinates(from: """
//                 
//   ATTN...WFO...DLH...MPX...DMX...FGF...FSD...ABR...
//
//   LAT...LON   43289764 48459445 48459097 43289447 43289764 
//
//   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH                       
//""")
//        let testPoly = MKPolygon(coordinates: coords ?? [], count: coords?.count ?? 0)
//        testPoly.title = "HIGH"
//
//        let multi = MKMultiPolygon([testPoly])
//        
//        mapView.addOverlays(multi.polygons)
        mapView.addOverlays(polygonList.polygons)
//        mapView.addAnnotation(annotation)
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove existing overlays
        uiView.removeOverlays(uiView.overlays)

        // Add new overlays from the updated polygonList
        uiView.addOverlays(polygonList.polygons)
        
        
//        let coords = MesoGeometry.coordinates(from: """
//                   
//   ATTN...WFO...DLH...MPX...DMX...FGF...FSD...ABR...
//
//   LAT...LON   43289764 48459445 48459097 43289447 43289764 
//
//   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH                           
//""")
//        let testPoly = MKPolygon(coordinates: coords ?? [], count: coords?.count ?? 0)
//        testPoly.title = "HIGH"
//        let multi = MKMultiPolygon([testPoly])
//        
//        uiView.addOverlays(multi.polygons)
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }
}

//#Preview {
//    CONUSMapView()
//}
