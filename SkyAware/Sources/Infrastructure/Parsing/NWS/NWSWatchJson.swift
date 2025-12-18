//
//  NWSWatchJson.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/8/25.
//

import Foundation

import Foundation

// MARK: - Root

public struct NWSWatchJson: Codable, Sendable {
//    public let context: [String]
    public let type: String
    public let features: [NWSWatchFeatureDTO]?
    public let title: String?
    public let updated: Date?
    public let pagination: NWSPaginationDTO?

    enum CodingKeys: String, CodingKey {
//        case context = "@context"
        case type
        case features
        case title
        case updated
        case pagination
    }
}

// MARK: - Feature

public struct NWSWatchFeatureDTO: Codable, Sendable {
    public let context: [String]?
    public let id: String
    public let type: String
    public let geometry: NWSGeometryDTO?
    public let properties: NWSWatchPropertiesDTO

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case geometry
        case properties
    }
}

// MARK: - Geometry

public struct NWSGeometryDTO: Codable, Sendable {
    public let type: String
    public let coordinates: [Double]
    public let bbox: [Double]?

    // If you later see Polygon/MultiPolygon, adjust this shape accordingly.
}

// MARK: - Properties

public struct NWSWatchPropertiesDTO: Codable, Sendable {
    public let id: String
    public let areaDesc: String
    public let geocode: NWSGeocodeDTO?
    public let affectedZones: [String]?
    public let references: [NWSReferenceDTO]?

    public let sent: Date?
    public let effective: Date?
    public let onset: Date?
    public let expires: Date?
    public let ends: Date?

    public let status: String?        // e.g. "Actual"
    public let messageType: String?   // e.g. "Alert"
    public let category: String?      // e.g. "Met"
    public let severity: String?      // e.g. "Extreme"
    public let certainty: String?     // e.g. "Observed"
    public let urgency: String?       // e.g. "Immediate"

    public let event: String?
    public let sender: String?
    public let senderName: String?

    public let headline: String?
    public let description: String?
    public let instruction: String?
    public let response: String?      // e.g. "Shelter"

    public let parameters: [String: [String]]?
    public let scope: String?
    public let code: String?
    public let language: String?
    public let web: String?
    public let eventCode: [String: [String]]?

    enum CodingKeys: String, CodingKey {
        case id
        case areaDesc
        case geocode
        case affectedZones
        case references

        case sent
        case effective
        case onset
        case expires
        case ends

        case status
        case messageType
        case category
        case severity
        case certainty
        case urgency

        case event
        case sender
        case senderName

        case headline
        case description
        case instruction
        case response

        case parameters
        case scope
        case code
        case language
        case web
        case eventCode
    }
}

// MARK: - Nested types

public struct NWSGeocodeDTO: Codable, Sendable {
    public let ugc: [String]?
    public let same: [String]?

    enum CodingKeys: String, CodingKey {
        case ugc = "UGC"
        case same = "SAME"
    }
}

public struct NWSReferenceDTO: Codable, Sendable {
    public let id: String
    public let identifier: String
    public let sender: String
    public let sent: Date

    enum CodingKeys: String, CodingKey {
        case id = "@id"
        case identifier
        case sender
        case sent
    }
}

public struct NWSPaginationDTO: Codable, Sendable {
    public let next: String?
}
