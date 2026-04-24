//
//  DeviceAlertPayload.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

public enum DeviceAlertPayloadError: Error, Sendable {
    case missingRequired(field: String)
    case invalidGeometryJSON
}

public enum DeviceAlertGeometry: Sendable, Codable, Equatable {
    case polygon(rings: [[DeviceAlertCoordinate]])
    case multiPolygon(polygons: [[[DeviceAlertCoordinate]]])

    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    private enum GeometryType: String, Codable {
        case polygon = "Polygon"
        case multiPolygon = "MultiPolygon"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(GeometryType.self, forKey: .type)

        switch type {
        case .polygon:
            let rings = try container.decode([[DeviceAlertCoordinate]].self, forKey: .coordinates)
            self = .polygon(rings: rings)
        case .multiPolygon:
            let polygons = try container.decode([[[DeviceAlertCoordinate]]].self, forKey: .coordinates)
            self = .multiPolygon(polygons: polygons)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .polygon(let rings):
            try container.encode(GeometryType.polygon, forKey: .type)
            try container.encode(rings, forKey: .coordinates)
        case .multiPolygon(let polygons):
            try container.encode(GeometryType.multiPolygon, forKey: .type)
            try container.encode(polygons, forKey: .coordinates)
        }
    }
}

/// GeoJSON-like transport coordinate stored as `[longitude, latitude]`.
/// Convert to map-native coordinate types only at the rendering edge.
public struct DeviceAlertCoordinate: Sendable, Codable, Equatable {
    public let longitude: Double
    public let latitude: Double

    public init(longitude: Double, latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        longitude = try container.decode(Double.self)
        latitude = try container.decode(Double.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(longitude)
        try container.encode(latitude)
    }
}

// TODO: Package this logic to share between SkyAware and Arcus-Signal
public struct DeviceAlertPayload: Sendable, Codable {
    // MARK: Identity
    let id: UUID // Series Id
    let event: String // event property in the message Tornado Watch
    let currentRevisionUrn: String
    let currentRevisionSent: Date?
    let messageType: String

    // MARK: Lifecycle
    let state: String // Active|Expired|Cancelled
    let created: Date
    let updated: Date
    let lastSeenActive: Date
    
    // MARK: Timing
    let sent: Date? // time of the origination of message itself
    let effective: Date? // goes into effect
    let onset: Date? // beginning of the event in message
    let expires: Date? // alert message expiration
    let ends: Date?
    
    // MARK: Severity inputs (normalized)
    let severity: String
    let urgency: String
    let certainty: String
    
    // MARK: Human-facing metadata
    let areaDesc: String?
    let senderName: String?
    let headline: String?
    let description: String?
    let instructions: String?
    let response: String?
    
    // Arcus can return cell-only matches without UGC metadata.
    let ugc: [String]?
    var h3Cells: [Int64]?
    let geometry: DeviceAlertGeometry?
    
    // CAP Params
    let tornadoDetection: String?
    let tornadoDamageThreat: String?
    let maxWindGust: String?
    let maxHailSize: String?
    let windThreat: String?
    let hailThreat: String?
    let thunderstormDamageThreat: String?
    let flashFloodDetection: String?
    let flashFloodDamageThreat: String?

}
