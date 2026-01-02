//
//  WatchContext.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/2/26.
//

import Foundation
import CoreLocation

struct WatchContext: Sendable {
    let now: Date
    let localTZ: TimeZone
    let location: CLLocationCoordinate2D
    let placeMark: String
    let watches: [WatchRowDTO]
//    let quietHours: ClosedRange<Int>?
//    let placeMark: String
    
    init(
        now: Date,
        localTZ: TimeZone,
        location: CLLocationCoordinate2D,
        placeMark: String,
        watches: [WatchRowDTO]
    ) {
        self.now = now
        self.localTZ = localTZ
        self.watches = watches
        self.placeMark = placeMark
        self.location = location
    }
}
