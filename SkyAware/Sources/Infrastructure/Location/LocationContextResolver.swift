//
//  LocationContextResolver.swift
//  SkyAware
//
//  Created by Codex on 3/28/26.
//

import CoreLocation
import Foundation
import OSLog

struct LocationContext: Sendable, Equatable {
    let snapshot: LocationSnapshot
    let h3Cell: Int64
    let grid: GridPointSnapshot

    var refreshKey: RefreshKey {
        .init(
            h3Cell: h3Cell,
            countyCode: grid.countyCode ?? "",
            fireZone: grid.fireZone ?? "",
            gridKey: GridRefreshKey(coord: snapshot.coordinates)
        )
    }

    struct RefreshKey: Hashable, Sendable {
        let h3Cell: Int64
        let countyCode: String
        let fireZone: String
        let gridKey: GridRefreshKey
    }
}

enum LocationContextError: Error, Equatable {
    case locationUnavailable
    case authorizationTimeout
    case locationTimeout
    case missingH3Cell
    case missingRegionContext
}

protocol LocationContextResolving: Sendable {
    func prepareCurrentContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async throws -> LocationContext

    func resolveContext(
        from snapshot: LocationSnapshot,
        maximumAcceptedLocationAge: TimeInterval?,
        placemarkTimeout: Double
    ) async throws -> LocationContext
}

actor LocationContextResolver: LocationContextResolving {
    typealias AuthorizationStatusProvider = @Sendable () async -> CLAuthorizationStatus
    typealias AuthorizationRequester = @Sendable (Bool) async -> Void
    typealias CurrentLocationRefresher = @Sendable (Double) async -> Bool

    private let locationClient: LocationClient
    private let locationProvider: LocationProvider
    private let gridPointProvider: GridPointProvider
    private let contextPusher: any LocationContextPushing
    private let authorizationStatusProvider: AuthorizationStatusProvider
    private let authorizationRequester: AuthorizationRequester
    private let refreshCurrentLocation: CurrentLocationRefresher
    private let logger = Logger.locationContextResolver

    init(
        locationClient: LocationClient,
        locationProvider: LocationProvider,
        gridPointProvider: GridPointProvider,
        contextPusher: any LocationContextPushing = NoOpLocationContextPusher(),
        authorizationStatusProvider: @escaping AuthorizationStatusProvider,
        authorizationRequester: @escaping AuthorizationRequester,
        refreshCurrentLocation: @escaping CurrentLocationRefresher
    ) {
        self.locationClient = locationClient
        self.locationProvider = locationProvider
        self.gridPointProvider = gridPointProvider
        self.contextPusher = contextPusher
        self.authorizationStatusProvider = authorizationStatusProvider
        self.authorizationRequester = authorizationRequester
        self.refreshCurrentLocation = refreshCurrentLocation
    }

    func prepareCurrentContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        authorizationTimeout: Double = 30,
        locationTimeout: Double = 12,
        maximumAcceptedLocationAge: TimeInterval = 5 * 60,
        placemarkTimeout: Double = 8
    ) async throws -> LocationContext {
        var authorizationStatus = await authorizationStatusProvider()

        if showsAuthorizationPrompt && authorizationStatus == .notDetermined {
            await authorizationRequester(true)
            authorizationStatus = try await waitForAuthorizationResolution(timeout: authorizationTimeout)
        }

        guard authorizationStatus.isLocationAuthorized else {
            throw LocationContextError.locationUnavailable
        }

        let didRefreshCurrentLocation = requiresFreshLocation
            ? await refreshCurrentLocation(locationTimeout)
            : false

        if didRefreshCurrentLocation,
           let refreshedSnapshot = await locationClient.snapshot(),
           Self.isAccepted(snapshot: refreshedSnapshot, maximumAge: maximumAcceptedLocationAge) {
            return try await resolveContext(
                from: refreshedSnapshot,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: placemarkTimeout
            )
        }

        if let cachedSnapshot = await locationClient.snapshot(),
           Self.isAccepted(snapshot: cachedSnapshot, maximumAge: maximumAcceptedLocationAge) {
            return try await resolveContext(
                from: cachedSnapshot,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: placemarkTimeout
            )
        }

        let stream = await locationClient.updates()
        let snapshot: LocationSnapshot?
        do {
            snapshot = try await withTimeout(timeout: locationTimeout) {
                for await snapshot in stream {
                    if Self.isAccepted(snapshot: snapshot, maximumAge: maximumAcceptedLocationAge) {
                        return snapshot
                    }
                }
                return nil
            }
        } catch OtherErrors.timeoutError {
            throw LocationContextError.locationTimeout
        }

        guard let snapshot else {
            throw LocationContextError.locationTimeout
        }

        return try await resolveContext(
            from: snapshot,
            maximumAcceptedLocationAge: maximumAcceptedLocationAge,
            placemarkTimeout: placemarkTimeout
        )
    }

    func resolveContext(
        from snapshot: LocationSnapshot,
        maximumAcceptedLocationAge: TimeInterval? = nil,
        placemarkTimeout: Double = 8
    ) async throws -> LocationContext {
        if let maximumAcceptedLocationAge,
           !Self.isAccepted(snapshot: snapshot, maximumAge: maximumAcceptedLocationAge) {
            throw LocationContextError.locationTimeout
        }

        let enrichedSnapshot = await locationProvider.ensurePlacemark(
            for: snapshot.coordinates,
            timeout: placemarkTimeout
        )

        guard let h3Cell = enrichedSnapshot.h3Cell else {
            logger.notice("Rejecting location context because h3 cell is unavailable")
            throw LocationContextError.missingH3Cell
        }

        guard let grid = await gridPointProvider.resolveGridPoint(for: enrichedSnapshot.coordinates),
              let countyCode = grid.countyCode,
              let fireZone = grid.fireZone,
              !countyCode.isEmpty,
              !fireZone.isEmpty else {
            logger.notice("Rejecting location context because county/fire zone metadata is incomplete")
            throw LocationContextError.missingRegionContext
        }

        let context = LocationContext(snapshot: enrichedSnapshot, h3Cell: h3Cell, grid: grid)
        await contextPusher.enqueue(context)
        return context
    }

    private func waitForAuthorizationResolution(timeout: Double) async throws -> CLAuthorizationStatus {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let status = await authorizationStatusProvider()
            if status != .notDetermined {
                return status
            }
            try? await Task.sleep(for: .milliseconds(100))
        }

        logger.notice("Timed out waiting for location authorization to resolve")
        throw LocationContextError.authorizationTimeout
    }

    private static func isAccepted(snapshot: LocationSnapshot, maximumAge: TimeInterval) -> Bool {
        let ageSeconds = max(0, Date().timeIntervalSince(snapshot.timestamp))
        return ageSeconds <= maximumAge
    }
}

extension CLAuthorizationStatus {
    var isLocationAuthorized: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
}
