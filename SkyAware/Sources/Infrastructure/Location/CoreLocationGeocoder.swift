//
//  CoreLocationGeocoder.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import Foundation
import CoreLocation

// MARK: - Geocoding Abstraction
protocol LocationGeocoding: Sendable {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String
}

actor CoreLocationGeocoder: LocationGeocoding {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        // Use a request-scoped geocoder to avoid overlapping operations on a shared
        // CLGeocoder instance, which can cancel in-flight requests unexpectedly.
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let places = try await geocoder.reverseGeocodeLocation(location)
        guard let p = places.first else { throw GeocodeError.noResults }
        return [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
    }
}
