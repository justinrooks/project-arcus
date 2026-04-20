//
//  WatchContext.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import CoreLocation
import Foundation

@available(*, deprecated, message: "Remove References")
struct WatchContext: Sendable {
    let now: Date
    let localTZ: TimeZone
    let location: CLLocationCoordinate2D
    let placeMark: String
    let watches: [WatchRowDTO]
}
