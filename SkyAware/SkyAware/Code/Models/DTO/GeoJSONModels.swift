//
//  GeoJSONModels.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/1/25.
//

import Foundation
import MapKit

struct GeoJsonResult {
    let product: GeoJSONProduct
    let featureCollection: GeoJSONFeatureCollection
}

// Top-level container
struct GeoJSONFeatureCollection: Decodable {
    let type: String
    let features: [GeoJSONFeature]
}

// A single feature (risk polygon)
struct GeoJSONFeature: Decodable {
    let type: String
    let geometry: GeoJSONGeometry
    let properties: GeoJSONProperties
}

// Geometry object: supports MultiPolygon
struct GeoJSONGeometry: Decodable {
    let type: String
    let coordinates: [[[[Double]]]]  // [[[ [lon, lat], ... ]]]
}

// Metadata about the polygon (risk label, stroke/fill color, etc.)
struct GeoJSONProperties: Decodable {
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

struct GeoPolygonEntity: Sendable, Codable {
    var title: String
    var coordinates: [Coordinate2D] // Use Coordinate2D from elsewhere in the project
    
    init(title: String, coordinates: [Coordinate2D]) {
        self.title = title
        self.coordinates = coordinates
    }
}

extension GeoJSONFeature {
    /// Creates the MKMultiPolygon object from the array of GeoJSONFeatures provided
    /// - Parameter polyTitle: the string title to apply to each polygon
    /// - Returns: MKMultiPolygon ready for rendering on a map
    @available(*, deprecated, message: "Use newFunction() instead.", renamed: "createPolygonEntities()")
    func createPolygons(polyTitle: String) -> [MKPolygon] {
        guard geometry.type == "MultiPolygon" else { return [] }
        
        return geometry.coordinates.flatMap { polygonGroup in
            polygonGroup.map { ring in
                let coords = ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                let poly = MKPolygon(coordinates: coords, count: coords.count)
                poly.title = polyTitle
                return poly
            }
        }
    }
    
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
