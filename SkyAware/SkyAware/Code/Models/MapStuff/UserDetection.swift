//
//  UserDetection.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import Foundation

// TODO: USER DETECTION LOGIC

//                    let bennett = CLLocationCoordinate2D(latitude: 39.75288661683443, longitude: -104.44886203922174)
//                    let lynchburg = CLLocationCoordinate2D(latitude: 37.41452581529873, longitude: -79.14424092499404)
//                    let winchester = CLLocationCoordinate2D(latitude: 39.184288393778644, longitude: -78.16016579706778)
//                    let Hancock = CLLocationCoordinate2D(latitude: 39.700116777481135, longitude: -78.19682012003283)
//                    let Waynesboro = CLLocationCoordinate2D(latitude: 39.75605469167874, longitude: -77.56697710760784)
//
//
//
//                                    var bInPoly = isUserInPolygon(user: bennett, polygonCoords: closed)
//                    var lInPoly = isUserInPolygon(user: lynchburg, polygonCoords: closed) //True
//                    var wcInPoly = isUserInPolygon(user: winchester, polygonCoords: closed)
//                    var hInPoly = isUserInPolygon(user: Hancock, polygonCoords: closed)
//                    var wInPoly = isUserInPolygon(user: Waynesboro, polygonCoords: closed)
//
//                }


//func isUserInPolygon(user: CLLocationCoordinate2D, polygonCoords: [CLLocationCoordinate2D]) -> Bool {
//    let mkPolygon = MKPolygon(coordinates: polygonCoords, count: polygonCoords.count)
//    let renderer = MKPolygonRenderer(polygon: mkPolygon)
//    renderer.createPath()
//    let point = MKMapPoint(user)
//    let cgPoint = renderer.point(for: point)
//    return renderer.path.contains(cgPoint)
//}

//func isUserInAnyPolygon(user: CLLocationCoordinate2D, polygonCoords: [CLLocationCoordinate2D]) -> Bool {
//    // Step 1: Group coordinates into disjoint sub-polygons using `CLLocationCoordinate2D(latitude: 0, longitude: 0)` as a delimiter
//    let subPolygons = splitIntoSubPolygons(polygonCoords)
//    
//    // Step 2: Convert user location to map point once
//    let userMapPoint = MKMapPoint(user)
//    
//    for coords in subPolygons {
//        let mkPolygon = MKPolygon(coordinates: coords, count: coords.count)
//        let renderer = MKPolygonRenderer(polygon: mkPolygon)
//        renderer.createPath() // Force path generation
//        let cgPoint = renderer.point(for: userMapPoint)
//        
//        if let path = renderer.path, path.contains(cgPoint) {
//            return true
//        }
//    }
//    
//    return false
//}

//func splitIntoSubPolygons(_ coords: [CLLocationCoordinate2D]) -> [[CLLocationCoordinate2D]] {
//    var result: [[CLLocationCoordinate2D]] = []
//    var current: [CLLocationCoordinate2D] = []
//    
//    for coord in coords {
//        if coord.latitude == 0 && coord.longitude == 0 {
//            if !current.isEmpty {
//                result.append(current)
//                current = []
//            }
//        } else {
//            current.append(coord)
//        }
//    }
//    
//    if !current.isEmpty {
//        result.append(current)
//    }
//    
//    return result
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
