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
        mapView.showsUserLocation = true

        // Zoom the map to show the entire US
        let center = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795) // center of CONUS
        let region = MKCoordinateRegion(center: center, latitudinalMeters: 5000000, longitudinalMeters: 5000000)
        mapView.setRegion(region, animated: true)

        // Add boundary overlays
        mapView.addOverlays(polygonList.polygons)
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove existing overlays
        uiView.removeOverlays(uiView.overlays)

        // Add new overlays from the updated polygonList
        uiView.addOverlays(polygonList.polygons)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.lineWidth = 1

                if let title = polygon.title?.uppercased() {
                    if title.contains("MRGL") {
                        let fill = UIColor(hue: 0.33, saturation: 0.5, brightness: 0.8, alpha: 0.3)
                        let stroke = UIColor.green
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("SLGT") {
                        let fill = UIColor.yellow.withAlphaComponent(0.3)
                        let stroke = UIColor.yellow
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("ENH") {
                        let fill = UIColor.orange.withAlphaComponent(0.4)
                        let stroke = UIColor.orange
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("MDT") {
                        let fill = UIColor.red.withAlphaComponent(0.5)
                        let stroke = UIColor.red
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("HIGH") {
                        let fill = UIColor.purple.withAlphaComponent(0.5)
                        let stroke = UIColor.purple
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("WIND") {
                        let fill = UIColor.systemTeal.withAlphaComponent(0.3)
                        let stroke = UIColor.systemTeal
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("HAIL") {
                        let fill = UIColor.systemBlue.withAlphaComponent(0.3)
                        let stroke = UIColor.systemBlue
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else if title.contains("TOR") {
                        let fill = UIColor.systemRed.withAlphaComponent(0.5)
                        let stroke = UIColor.systemRed
                        renderer.strokeColor = stroke
                        renderer.fillColor = fill
                    } else {
                        renderer.strokeColor = UIColor.systemOrange
                        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.15)
                    }
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
