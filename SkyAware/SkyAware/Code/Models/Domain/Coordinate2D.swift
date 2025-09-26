//
//  Coordinate2D.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import CoreLocation

struct Coordinate2D: Sendable, Codable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        
    }
}

extension Coordinate2D {
    init(_ location: CLLocationCoordinate2D) {
        self.latitude = location.latitude
        self.longitude = location.longitude
    }
    

    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
