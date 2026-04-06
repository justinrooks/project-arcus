//
//  GeoPolygonEntity.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/22/25.
//

import Foundation
import CoreLocation

struct GeoPolygonEntity: Sendable, Codable {
    var title: String
    var coordinates: [Coordinate2D] // Use Coordinate2D from elsewhere in the project
    
    var minLat: Double?
    var maxLat: Double?
    var minLon: Double?
    var maxLon: Double?
    
    init(title: String, coordinates: [Coordinate2D]) {
        self.title = title
        self.coordinates = coordinates
        
        if !coordinates.isEmpty {
            let lats = coordinates.map(\.latitude)
            let lons = coordinates.map(\.longitude)
            
            self.minLat = lats.min()
            self.maxLat = lats.max()
            self.minLon = lons.min()
            self.maxLon = lons.max()
        } else {
            self.minLat = nil
            self.maxLat = nil
            self.minLon = nil
            self.maxLon = nil
        }
    }
}

extension GeoPolygonEntity {
    nonisolated var bbox: GeoBBox? {
        guard let minLat, let maxLat, let minLon, let maxLon else { return nil }
        
        return GeoBBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
    
    nonisolated var ringCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.location }
    }
}
