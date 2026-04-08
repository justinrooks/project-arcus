//
//  GeoJSONModels.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/1/25.
//

import Foundation
import MapKit

// Top-level container
struct GeoJSONFeatureCollection: Codable {
    let type: String //FeatureCollection
    let features: [GeoJSONFeature]
}

// A single feature (risk polygon)
struct GeoJSONFeature: Codable {
    let type: String //Feature
    let geometry: GeoJSONGeometry
    let properties: GeoJSONProperties
}

// Geometry object: supports MultiPolygon
struct GeoJSONGeometry: Codable {
    let type: String //MultiPolygon
    let coordinates: [[[[Double]]]]  // [[[ [lon, lat], ... ]]]
}

// Metadata about the polygon (risk label, stroke/fill color, etc.)
struct GeoJSONProperties: Codable {
    let DN: Int
    let VALID: String
    let EXPIRE: String
    let ISSUE: String
    let LABEL: String
    let LABEL2: String
    let stroke: String
    let fill: String
}

extension GeoJSONFeatureCollection {
    static var empty: GeoJSONFeatureCollection {
        GeoJSONFeatureCollection(type: "FeatureCollection", features: [])
    }
}

extension GeoJSONFeature {
    /// Creates GeoPolygonEntity objects from the polygon rings
    /// - Parameter polyTitle: the title to assign to each GeoPolygonEntity
    /// - Returns: Array of GeoPolygonEntity instances
    func createPolygonEntities(polyTitle: String) -> [GeoPolygonEntity] {
        guard geometry.type == "MultiPolygon" else { return [] }
        
        return geometry.coordinates.flatMap { polygonGroup in
            polygonGroup.map { ring in
                let coords: [Coordinate2D] = ring.map { pair in
                    Coordinate2D(latitude: pair[1], longitude: pair[0])
                }
                return GeoPolygonEntity(title: polyTitle, coordinates: coords)
            }
        }
    }
}
