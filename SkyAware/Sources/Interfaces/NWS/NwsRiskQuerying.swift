//
//  NwsRiskQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/21/25.
//

import Foundation
import CoreLocation

protocol NwsRiskQuerying: Sendable {
    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchDTO]
}
