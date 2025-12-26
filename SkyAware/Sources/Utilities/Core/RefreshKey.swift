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

struct GridRefreshKey: Equatable {
    let coord: CLLocationCoordinate2D
//        let timestamp: Date
    
    static func == (lhs: GridRefreshKey, rhs: GridRefreshKey) -> Bool {
        lhs.coord.latitude == rhs.coord.latitude &&
        lhs.coord.longitude == rhs.coord.longitude //&&
//            lhs.timestamp == rhs.timestamp
    }
}
