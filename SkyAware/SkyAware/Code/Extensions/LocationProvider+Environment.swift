//
//  LocationProvider+Environment.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/8/25.
//

import SwiftUI

extension LocationClient {
    static let offline = LocationClient (
        snapshot: {
            () async -> LocationSnapshot? in nil
        },
        updates: {
            AsyncStream<LocationSnapshot> { c in
                c.finish()
            }
        })
    
    static let test = LocationClient(
        snapshot: { () async -> LocationSnapshot? in
            .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            )
        },
        updates: { () -> AsyncStream<LocationSnapshot> in
            AsyncStream<LocationSnapshot> { c in
                c.yield(.init(
                    coordinates: .init(latitude: 39.75, longitude: -104.44),
                    timestamp: .now,
                    accuracy: 20,
                    placemarkSummary: "Bennett, CO"
                ))
                c.finish()
            }
        }
    )

}

extension EnvironmentValues {
    @Entry var locationClient: LocationClient = .offline //.init(snapshot: {nil }, updates: {AsyncStream { _ in } } )
}
