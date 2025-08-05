//
//  GeoJSONModels.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/1/25.
//

import Foundation
import MapKit

struct GeoJsonResult {
    let product: Product
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
