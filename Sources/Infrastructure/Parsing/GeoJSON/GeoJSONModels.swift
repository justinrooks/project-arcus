//
//  GeoJSONModels.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/1/25.
//

import Foundation
import MapKit

// Top-level container
struct GeoJSONFeatureCollection: Codable, Sendable {
    let type: String //FeatureCollection
    let features: [GeoJSONFeature]
}

// A single feature (risk polygon)
struct GeoJSONFeature: Codable, Sendable {
    let type: String //Feature
    let geometry: GeoJSONGeometry
    let properties: GeoJSONProperties
}

// Geometry object: supports material MultiPolygon geometry and empty GeometryCollection sentinels.
struct GeoJSONGeometry: Codable, Sendable {
    let type: String
    let coordinates: [[[[Double]]]]
    let geometries: [GeoJSONNestedGeometry]

    init(
        type: String,
        coordinates: [[[[Double]]]] = [],
        geometries: [GeoJSONNestedGeometry] = []
    ) {
        self.type = type
        self.coordinates = coordinates
        self.geometries = geometries
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
        case geometries
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        coordinates = try container.decodeIfPresent([[[[Double]]]].self, forKey: .coordinates) ?? []
        geometries = try container.decodeIfPresent([GeoJSONNestedGeometry].self, forKey: .geometries) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if type == "MultiPolygon" || coordinates.isEmpty == false {
            try container.encode(coordinates, forKey: .coordinates)
        }
        if type == "GeometryCollection" || geometries.isEmpty == false {
            try container.encode(geometries, forKey: .geometries)
        }
    }
}

struct GeoJSONNestedGeometry: Codable, Sendable {
    let type: String
}

// Metadata about the polygon (risk label, stroke/fill color, etc.)
struct GeoJSONProperties: Codable, Sendable {
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

    var materialPolygonCount: Int {
        features.reduce(into: 0) { count, feature in
            count += feature.materialPolygonCount
        }
    }
}

extension GeoJSONFeature {
    var materialPolygonCount: Int {
        guard geometry.type == "MultiPolygon" else { return 0 }
        return geometry.coordinates.reduce(into: 0) { count, polygonGroup in
            count += polygonGroup.count
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
