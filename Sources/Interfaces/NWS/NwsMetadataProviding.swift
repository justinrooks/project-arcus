//
//  NwsMetadataProviding.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/26/25.
//

import Foundation
import CoreLocation

protocol NwsMetadataProviding: Sendable {
    func fetchPointMetadata(for point: CLLocationCoordinate2D) async -> Void
}
