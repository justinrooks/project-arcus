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

protocol DurableLocationContextCaching: Sendable {
    func load() -> LocationContext?
    func save(_ context: LocationContext)
    func invalidate()
}

private struct PersistedDurableLocationContext: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let accuracy: Double
    let h3Cell: Int64
    let nwsId: String
    let gridId: String
    let gridX: Int
    let gridY: Int
    let forecastURL: URL?
    let forecastHourlyURL: URL?
    let forecastGridDataURL: URL?
    let observationStationsURL: URL?
    let timeZoneId: String?
    let radarStationId: String?
    let forecastZone: String?
    let countyCode: String
    let fireZone: String

    init(context: LocationContext) {
        version = Self.currentVersion
        latitude = context.snapshot.coordinates.latitude
        longitude = context.snapshot.coordinates.longitude
        timestamp = context.snapshot.timestamp
        accuracy = context.snapshot.accuracy
        h3Cell = context.h3Cell
        nwsId = context.grid.nwsId
        gridId = context.grid.gridId
        gridX = context.grid.gridX
        gridY = context.grid.gridY
        forecastURL = context.grid.forecastURL
        forecastHourlyURL = context.grid.forecastHourlyURL
        forecastGridDataURL = context.grid.forecastGridDataURL
        observationStationsURL = context.grid.observationStationsURL
        timeZoneId = context.grid.timeZoneId
        radarStationId = context.grid.radarStationId
        forecastZone = context.grid.forecastZone
        countyCode = context.grid.countyCode ?? ""
        fireZone = context.grid.fireZone ?? ""
    }

    var context: LocationContext? {
        guard version == Self.currentVersion,
              latitude.isFinite,
              longitude.isFinite,
              CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)),
              timestamp.timeIntervalSinceReferenceDate.isFinite,
              accuracy.isFinite,
              accuracy > 0,
              h3Cell != 0,
              nwsId.isEmpty == false,
              gridId.isEmpty == false,
              countyCode.isEmpty == false,
              fireZone.isEmpty == false else {
            return nil
        }

        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: timestamp,
            accuracy: accuracy,
            placemarkSummary: nil,
            h3Cell: h3Cell
        )
        let grid = GridPointSnapshot(
            nwsId: nwsId,
            latitude: latitude,
            longitude: longitude,
            gridId: gridId,
            gridX: gridX,
            gridY: gridY,
            forecastURL: forecastURL,
            forecastHourlyURL: forecastHourlyURL,
            forecastGridDataURL: forecastGridDataURL,
            observationStationsURL: observationStationsURL,
            city: nil,
            state: nil,
            timeZoneId: timeZoneId,
            radarStationId: radarStationId,
            forecastZone: forecastZone,
            countyCode: countyCode,
            fireZone: fireZone,
            countyLabel: nil,
            fireZoneLabel: nil
        )
        return LocationContext(snapshot: snapshot, h3Cell: h3Cell, grid: grid)
    }
}

struct DurableLocationContextCache: DurableLocationContextCaching {
    private let suiteName: String
    private let key: String
    private let nowProvider: @Sendable () -> Date

    init(
        suiteName: String = "com.justinrooks.skyaware",
        key: String = "location.durableContext.v1",
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.suiteName = suiteName
        self.key = key
        self.nowProvider = nowProvider
    }

    func load() -> LocationContext? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let persisted = try? decoder.decode(PersistedDurableLocationContext.self, from: data),
              let context = persisted.context,
              context.snapshot.timestamp <= nowProvider() else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return context
    }

    func save(_ context: LocationContext) {
        guard let persisted = PersistedDurableLocationContext(context: context).context else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(PersistedDurableLocationContext(context: persisted)) else { return }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
    }

    func invalidate() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: key)
    }
}

struct NoOpDurableLocationContextCache: DurableLocationContextCaching {
    func load() -> LocationContext? { nil }
    func save(_: LocationContext) {}
    func invalidate() {}
}
