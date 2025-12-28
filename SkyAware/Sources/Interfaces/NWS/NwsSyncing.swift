//
//  NwsSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/21/25.
//

import Foundation
import CoreLocation

protocol NwsSyncing: Sendable {
    func sync(for point: CLLocationCoordinate2D) async -> Void
}
