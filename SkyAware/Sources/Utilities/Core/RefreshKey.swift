//
//  RefreshKey.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/24/25.
//

import Foundation
import CoreLocation

struct RefreshKey: Equatable {
    let coord: CLLocationCoordinate2D
    let timestamp: Date
    
    static func == (lhs: RefreshKey, rhs: RefreshKey) -> Bool {
        lhs.coord.latitude == rhs.coord.latitude &&
        lhs.coord.longitude == rhs.coord.longitude &&
        lhs.timestamp == rhs.timestamp
    }
}

struct GridRefreshKey: Hashable, Sendable {
    let latitudeE4: Int
    let longitudeE4: Int

    init(coord: CLLocationCoordinate2D) {
        latitudeE4 = Self.quantize(coord.latitude)
        longitudeE4 = Self.quantize(coord.longitude)
    }

    private static func quantize(_ value: Double) -> Int {
        Int((value * 10_000).rounded(.towardZero))
    }
}
