//
//  PolygonHelpers.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/11/25.
//

import Foundation
import MapKit

enum PolygonHelpers {
    /// Determine if the user is in any of the provided polygons
    /// - Parameters:
    ///   - user: the users location
    ///   - mkPolygons: array of polygons to check
    /// - Returns: true if user is in any of the provided polygons, false otherwise
    static func isUserIn(user: CLLocationCoordinate2D, mkPolygons: [MKPolygon]) -> (Bool, Double) {
        var maxProbability: Double = 0.0
        var isInsideAny = false
        
        for polygon in mkPolygons {
            let isInside = inPoly(user: user, polygon: polygon)

            if isInside {
                isInsideAny = true
                
                if let title = polygon.title,
                   let valueString = title.split(separator: "%").first?.trimmingCharacters(in: .whitespaces),
                   let value = Double(valueString) {
                    maxProbability = max(maxProbability, value)
                }
            }
        }
        
        return (isInsideAny, maxProbability)
    }
    
    
    /// Determines if a location is inside a single polygon
    /// - Parameters:
    ///   - user: the users CLLocationCoordinate
    ///   - polygon: Polygon to check
    /// - Returns: true if location is within the provided polygon, false otherwise
    static func inPoly(user: CLLocationCoordinate2D, polygon: MKPolygon) -> Bool {
        let userMapPoint = MKMapPoint(user)
        var isInsideAny = false
        
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.createPath()
        let cgPoint = renderer.point(for: userMapPoint)
        
        if renderer.path.contains(cgPoint) {
            isInsideAny = true
         }
        
        return isInsideAny
    }
}
