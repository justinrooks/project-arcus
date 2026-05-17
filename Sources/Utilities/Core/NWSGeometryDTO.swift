//
//  NWSGeometryDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 5/16/26.
//

import Foundation

// MARK: - Geometry

public struct NWSGeometryDTO: Codable, Sendable {
    public let type: String
    public let coordinates: [Double]
    public let bbox: [Double]?

    // If you later see Polygon/MultiPolygon, adjust this shape accordingly.
}
