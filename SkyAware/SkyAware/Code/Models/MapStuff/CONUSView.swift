//
//  CONUSView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit

struct CONUSMapView: UIViewRepresentable {
    //let conusPolygons: [MKPolygon]
    let polygonList: MKMultiPolygon

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard

        // Zoom the map to show the entire US
        let center = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795) // center of CONUS
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 5000000, longitudinalMeters: 5000000)
        mapView.setRegion(region, animated: true)

        // Add boundary overlays
//        mapView.addOverlays(conusPolygons)
        
        polygonList.polygons.forEach { poly in
            mapView.addOverlay(poly)
        }
        //        testPoly.title = "SLGT"
        //        mapView.addOverlay(testPoly)
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.lineWidth = 1
                let softGreen = UIColor(red: 120/255, green: 180/255, blue: 120/255, alpha: 1.0)
                let paleSPCGreen = UIColor(red: 160/255, green: 210/255, blue: 160/255, alpha: 1.0)
                let slgtYellow = UIColor(red: 255/255, green: 215/255, blue: 0/255, alpha: 1.0)
                
                switch polygon.title ?? "" {
                case "MRGL":
                    renderer.strokeColor = softGreen
                    renderer.fillColor = softGreen.withAlphaComponent(0.15)
                case "SLGT":
                    renderer.strokeColor = slgtYellow
                    renderer.fillColor = slgtYellow.withAlphaComponent(0.5)
                default:
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.15)
                }
                
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func createMultiPolylineRenderer(for multiPolygon: MKMultiPolygon) -> MKMultiPolygonRenderer {
            let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
            renderer.fillColor = UIColor(named: "MultiPolygonOverlayFill")
            renderer.strokeColor = UIColor(named: "MultiPolygonOverlayStroke")
            renderer.lineWidth = 2.0


            return renderer
        }
    }
}

//#Preview {
//    CONUSMapView()
//}
