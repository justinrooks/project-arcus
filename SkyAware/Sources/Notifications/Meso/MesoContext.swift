//
//  MesoContext.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import CoreLocation

struct NotificationContext: Sendable {
    let now: Date
    let localTZ: TimeZone
    let location: CLLocationCoordinate2D
    let placeMark: String
}

struct MesoContext: Sendable {
    let now: Date
    let localTZ: TimeZone
    let location: CLLocationCoordinate2D
    let placeMark: String
    let mesos: [MdDTO]
//    let quietHours: ClosedRange<Int>?
//    let placeMark: String
    
    init(
        now: Date,
        localTZ: TimeZone,
        location: CLLocationCoordinate2D,
        placeMark: String,
        mesos: [MdDTO]
    ) {
        self.now = now
        self.localTZ = localTZ
        self.mesos = mesos
        self.placeMark = placeMark
        self.location = location
    }
}
