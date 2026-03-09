//
//  LocationSnapshotCache.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import CoreLocation
import Foundation

protocol LocationSnapshotCaching: Sendable {
    func load() -> LocationSnapshot?
    func save(_ snapshot: LocationSnapshot)
}

private struct PersistedLocationSnapshot: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let accuracy: CLLocationAccuracy
    let placemarkSummary: String?
    let h3Cell: Int64?

    init(snapshot: LocationSnapshot) {
        latitude = snapshot.coordinates.latitude
        longitude = snapshot.coordinates.longitude
        timestamp = snapshot.timestamp
        accuracy = snapshot.accuracy
        placemarkSummary = snapshot.placemarkSummary
        h3Cell = snapshot.h3Cell
    }

    var snapshot: LocationSnapshot {
        LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            timestamp: timestamp,
            accuracy: accuracy,
            placemarkSummary: placemarkSummary,
            h3Cell: h3Cell
        )
    }
}

struct LocationSnapshotCache: LocationSnapshotCaching {
    private let suiteName: String
    private let key: String

    init(
        suiteName: String = "com.justinrooks.skyaware",
        key: String = "location.lastSnapshot.v1"
    ) {
        self.suiteName = suiteName
        self.key = key
    }

    func load() -> LocationSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: key)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let persisted = try? decoder.decode(PersistedLocationSnapshot.self, from: data) else {
            return nil
        }

        let snapshot = persisted.snapshot
        guard CLLocationCoordinate2DIsValid(snapshot.coordinates) else {
            return nil
        }

        return snapshot
    }

    func save(_ snapshot: LocationSnapshot) {
        guard CLLocationCoordinate2DIsValid(snapshot.coordinates) else { return }

        let persisted = PersistedLocationSnapshot(snapshot: snapshot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(persisted) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }
}

struct NoOpLocationSnapshotCache: LocationSnapshotCaching {
    func load() -> LocationSnapshot? { nil }
    func save(_ snapshot: LocationSnapshot) {}
}
