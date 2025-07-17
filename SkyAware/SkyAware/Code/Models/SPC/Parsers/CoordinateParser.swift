//
//  CoordinateParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/10/25.
//

import Foundation
import CoreLocation

func parseForecastCoordinate(_ raw: String) -> CLLocationCoordinate2D? {
    guard raw.count == 8,
          let latHundo = Double(raw.prefix(4)),
          let lonHundo = Double(raw.suffix(4)) else {
        return nil
    }
    
    let lat = latHundo / 100.0
    let lon = -(lonHundo / 100.0)
    
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
}
