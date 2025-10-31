//
//  LocationThrottleConfig.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/30/25.
//

import Foundation
import CoreLocation

struct LocationThrottleConfig: Sendable {
    var minAccuracy: CLLocationAccuracy = 100 // Meters
    var minSeconds: TimeInterval = 8          // Suppress bursting
    var maxSilenceSeconds: TimeInterval = 60  // Force deliver at least every 60
    var baseMeters: CLLocationDistance = 1650
    var clampForeground: ClosedRange<Double> = 500...2000
}

struct DistancePolicy: Sendable {
    var baseMeters: Double
    
    func thresholdMeters(speedMps v: Double?) -> Double {
        let m: Double = {
            guard let v, v > 0 else { return 0.8 }
            if v < 1 { return 0.5 }
            if v < 5 { return 0.8 }
            if v < 15 { return 1.0 }
            return 1.6
        }()
        
        return baseMeters * m
    }
}
