//
//  UserDetection.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import Foundation

// MARK: Proximity to polygon

//import CoreLocation
//import MapKit
//
//func distanceFromPoint(_ point: CLLocationCoordinate2D, to polygon: MKPolygon) -> CLLocationDistance {
//    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polygon.pointCount)
//    polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
//
//    var minDistance: CLLocationDistance = .greatestFiniteMagnitude
//
//    for i in 0..<coords.count - 1 {
//        let a = coords[i]
//        let b = coords[i + 1]
//        let distance = distanceFromPoint(point, toSegment: (a, b))
//        minDistance = min(minDistance, distance)
//    }
//
//    return minDistance
//}
//
//func distanceFromPoint(_ p: CLLocationCoordinate2D, toSegment segment: (CLLocationCoordinate2D, CLLocationCoordinate2D)) -> CLLocationDistance {
//    let p0 = CLLocation(latitude: p.latitude, longitude: p.longitude)
//    let p1 = CLLocation(latitude: segment.0.latitude, longitude: segment.0.longitude)
//    let p2 = CLLocation(latitude: segment.1.latitude, longitude: segment.1.longitude)
//
//    // Compute the projection of point p onto the line segment p1–p2
//    let d1 = p1.distance(from: p2)
//    guard d1 != 0 else { return p0.distance(from: p1) }
//
//    let dx = segment.1.longitude - segment.0.longitude
//    let dy = segment.1.latitude - segment.0.latitude
//
//    let t = max(0, min(1, (
//        ((p.longitude - segment.0.longitude) * dx + (p.latitude - segment.0.latitude) * dy) /
//        (dx*dx + dy*dy)
//    )))
//
//    let proj = CLLocationCoordinate2D(
//        latitude: segment.0.latitude + t * dy,
//        longitude: segment.0.longitude + t * dx
//    )
//
//    return p0.distance(from: CLLocation(latitude: proj.latitude, longitude: proj.longitude))
//}
//
//let userLocation = CLLocationCoordinate2D(latitude: 39.74, longitude: -104.99)
//let polygon = yourTornadoMKPolygon
//
//let distanceInMeters = distanceFromPoint(userLocation, to: polygon)
//let distanceInMiles = distanceInMeters / 1609.34
//
//if distanceInMiles <= 25 {
//    print("⚠️ User is within 25 miles of the tornado polygon")
//}

//
//func isUserRightOfLine(user: CLLocationCoordinate2D, path: [CLLocationCoordinate2D]) -> Bool {
//    guard path.count >= 2 else { return false }
//    
//    for i in 0..<(path.count - 1) {
//        let a = path[i]
//        let b = path[i + 1]
//        
//        let ab = CGPoint(x: b.longitude - a.longitude, y: b.latitude - a.latitude)
//        let ap = CGPoint(x: user.longitude - a.longitude, y: user.latitude - a.latitude)
//        
//        let cross = ab.x * ap.y - ab.y * ap.x
//        
//        // If user is on the right side of at least one segment, consider them "included"
//        if cross < 0 {
//            return true
//        }
//    }
//    
//    return false
//}
