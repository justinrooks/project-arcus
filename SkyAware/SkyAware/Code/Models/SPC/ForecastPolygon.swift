//
//  ForecastPolygon.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/10/25.
//

import SwiftUI
import Foundation
import MapKit

struct ForecastPolygon: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let riskType: String
    let probability: Double
}

struct MapPolygonView: UIViewRepresentable {
    let forecastPolygons: [ForecastPolygon]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)

        for polygon in forecastPolygons {
            let mkPolygon = MKPolygon(coordinates: polygon.coordinates, count: polygon.coordinates.count)
            mkPolygon.title = polygon.riskType
            mapView.addOverlay(mkPolygon)
        }

        if let first = forecastPolygons.first?.coordinates.first {
            let region = MKCoordinateRegion(center: first, latitudinalMeters: 800_000, longitudinalMeters: 800_000)
            mapView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            switch polygon.title ?? "" {
            case "TORNADO":
                renderer.fillColor = .red.withAlphaComponent(0.3)
            case "HAIL":
                renderer.fillColor = .blue.withAlphaComponent(0.3)
            case "WIND":
                renderer.fillColor = .green.withAlphaComponent(0.3)
            case "SLGT":
                renderer.fillColor = .yellow.withAlphaComponent(0.4)
            case "MRGL":
                renderer.fillColor = .gray.withAlphaComponent(0.3)
            case "ENH":
                renderer.fillColor = .orange.withAlphaComponent(0.4)
            default:
                renderer.fillColor = .purple.withAlphaComponent(0.2)
            }
            renderer.strokeColor = .black
            renderer.lineWidth = 1
            return renderer
        }
    }
}

// MARK: - Story 4: Detect User Inside Any Risk Polygon

func isUserRightOfLine(user: CLLocationCoordinate2D, path: [CLLocationCoordinate2D]) -> Bool {
    guard path.count >= 2 else { return false }
    
    for i in 0..<(path.count - 1) {
        let a = path[i]
        let b = path[i + 1]
        
        let ab = CGPoint(x: b.longitude - a.longitude, y: b.latitude - a.latitude)
        let ap = CGPoint(x: user.longitude - a.longitude, y: user.latitude - a.latitude)
        
        let cross = ab.x * ap.y - ab.y * ap.x
        
        // If user is on the right side of at least one segment, consider them "included"
        if cross < 0 {
            return true
        }
    }
    
    return false
}

func isUserInPolygon(user: CLLocationCoordinate2D, polygonCoords: [CLLocationCoordinate2D]) -> Bool {
    let mkPolygon = MKPolygon(coordinates: polygonCoords, count: polygonCoords.count)
    let renderer = MKPolygonRenderer(polygon: mkPolygon)
    renderer.createPath()
    let point = MKMapPoint(user)
    let cgPoint = renderer.point(for: point)
    return renderer.path.contains(cgPoint)
}

func isUserInAnyPolygon(user: CLLocationCoordinate2D, polygonCoords: [CLLocationCoordinate2D]) -> Bool {
    // Step 1: Group coordinates into disjoint sub-polygons using `CLLocationCoordinate2D(latitude: 0, longitude: 0)` as a delimiter
    let subPolygons = splitIntoSubPolygons(polygonCoords)
    
    // Step 2: Convert user location to map point once
    let userMapPoint = MKMapPoint(user)
    
    for coords in subPolygons {
        let mkPolygon = MKPolygon(coordinates: coords, count: coords.count)
        let renderer = MKPolygonRenderer(polygon: mkPolygon)
        renderer.createPath() // Force path generation
        let cgPoint = renderer.point(for: userMapPoint)
        
        if let path = renderer.path, path.contains(cgPoint) {
            return true
        }
    }
    
    return false
}

func splitIntoSubPolygons(_ coords: [CLLocationCoordinate2D]) -> [[CLLocationCoordinate2D]] {
    var result: [[CLLocationCoordinate2D]] = []
    var current: [CLLocationCoordinate2D] = []
    
    for coord in coords {
        if coord.latitude == 0 && coord.longitude == 0 {
            if !current.isEmpty {
                result.append(current)
                current = []
            }
        } else {
            current.append(coord)
        }
    }
    
    if !current.isEmpty {
        result.append(current)
    }
    
    return result
}
