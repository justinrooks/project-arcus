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
    var coordinates: [Coordinate2D]
    var interiorCoordinates: [[Coordinate2D]]
    
    var minLat: Double?
    var maxLat: Double?
    var minLon: Double?
    var maxLon: Double?
    
    init(
        title: String,
        coordinates: [Coordinate2D],
        interiorCoordinates: [[Coordinate2D]] = []
    ) {
        self.title = title
        self.coordinates = coordinates
        self.interiorCoordinates = interiorCoordinates
        
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

    private enum CodingKeys: String, CodingKey {
        case title
        case coordinates
        case interiorCoordinates
        case minLat
        case maxLat
        case minLon
        case maxLon
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        coordinates = try container.decode([Coordinate2D].self, forKey: .coordinates)
        interiorCoordinates = try container.decodeIfPresent([[Coordinate2D]].self, forKey: .interiorCoordinates) ?? []
        minLat = try container.decodeIfPresent(Double.self, forKey: .minLat)
        maxLat = try container.decodeIfPresent(Double.self, forKey: .maxLat)
        minLon = try container.decodeIfPresent(Double.self, forKey: .minLon)
        maxLon = try container.decodeIfPresent(Double.self, forKey: .maxLon)
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
