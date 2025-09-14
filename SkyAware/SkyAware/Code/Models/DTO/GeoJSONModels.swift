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

extension GeoJSONFeature {
    /// Creates the MKMultiPolygon object from the array of GeoJSONFeatures provided
    /// - Parameter polyTitle: the string title to apply to each polygon
    /// - Returns: MKMultiPolygon ready for rendering on a map
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
}
