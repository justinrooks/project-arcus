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

extension GeoJSONProperties {
    func toString() -> String {
        return "\nDN: \(DN)\nVALID: \(VALID)\nEXPIRE: \(EXPIRE)\nISSUE: \(ISSUE)\nLABEL: \(LABEL)\nLABEL2: \(LABEL2)\nstroke: \(stroke)\nfill: \(fill)"
    }
    
    static func parse(from string: String) -> GeoJSONProperties? {
        var dict = [String: String]()

        string
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .forEach { line in
                let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return }
                dict[parts[0]] = parts[1]
            }

        guard
            let dnString = dict["DN"], let dn = Int(dnString),
            let valid = dict["VALID"],
            let expire = dict["EXPIRE"],
            let issue = dict["ISSUE"],
            let label = dict["LABEL"],
            let label2 = dict["LABEL2"],
            let stroke = dict["STROKE"],
            let fill = dict["FILL"]
        else {
            return nil
        }

        return GeoJSONProperties(
            DN: dn,
            VALID: valid,
            EXPIRE: expire,
            ISSUE: issue,
            LABEL: label,
            LABEL2: label2,
            stroke: stroke,
            fill: fill
        )
    }
}
