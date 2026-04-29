//
//  LocationSession.swift
//  SkyAware
//
//  Created by Codex on 8/15/25.
//

import CoreLocation
import Observation
import SwiftUI

enum LocationStartupState: Equatable {
    case idle
    case requestingAuthorization
    case acquiringLocation
    case resolvingContext
    case ready
    case failed(String)
}

@MainActor
@Observable
final class LocationSession {
    private let locationClient: LocationClient
    private let locationManager: LocationManager
    private let locationContextResolver: any LocationContextResolving

    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?
    @ObservationIgnored
    private var contextRefreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var currentScenePhase: ScenePhase = .inactive

    var currentSnapshot: LocationSnapshot?
    var currentContext: LocationContext?
    var authorizationStatus: CLAuthorizationStatus
    var accuracyAuthorization: CLAccuracyAuthorization?
    var startupState: LocationStartupState = .idle
    var reliabilityState: LocationReliabilityState {
        LocationReliabilityState(
            authorizationStatus: authorizationStatus,
            accuracyAuthorization: accuracyAuthorization
        )
    }

    init(
        locationClient: LocationClient,
        locationManager: LocationManager,
        locationContextResolver: any LocationContextResolving
    ) {
        self.locationClient = locationClient
        self.locationManager = locationManager
        self.locationContextResolver = locationContextResolver
        self.authorizationStatus = locationManager.authStatus
        self.accuracyAuthorization = locationManager.accuracyAuthorization

        locationManager.setAuthorizationChangeHandler { [weak self] status, accuracy in
            guard let self else { return }
            if self.authorizationStatus != status {
                self.authorizationStatus = status
            }
            if self.accuracyAuthorization != accuracy {
                self.accuracyAuthorization = accuracy
            }
            if status.isLocationAuthorized == false {
                self.currentContext = nil
                self.startupState = .failed("location-unavailable")
            }
        }

        updatesTask = Task { [weak self] in
            guard let self else { return }

            let initialSnapshot = await locationClient.snapshot()
            if Task.isCancelled { return }
            self.currentSnapshot = initialSnapshot

            let stream = await locationClient.updates()
            for await snapshot in stream {
                if Task.isCancelled { break }
                await self.handleSnapshotUpdate(snapshot)
            }
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        currentScenePhase = phase
        syncAuthorizationStatus()
        locationManager.updateMode(for: phase)
    }

    func requestInteractiveAuthorization() {
        locationManager.checkLocationAuthorization(isActive: true)
        syncAuthorizationStatus()
    }

    @discardableResult
    func requestAlwaysAuthorizationUpgradeIfNeeded() -> Bool {
        let didRequestUpgrade = locationManager.requestAlwaysAuthorizationUpgradeIfNeeded()
        syncAuthorizationStatus()
        return didRequestUpgrade
    }

    func openSettings() {
        locationManager.openSettings()
    }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        authorizationTimeout: Double = 30,
        locationTimeout: Double = 12,
        maximumAcceptedLocationAge: TimeInterval = 5 * 60,
        placemarkTimeout: Double = 8
    ) async -> LocationContext? {
        syncAuthorizationStatus()
        startupState = showsAuthorizationPrompt && authorizationStatus == .notDetermined
            ? .requestingAuthorization
            : .acquiringLocation

        do {
            let context = try await locationContextResolver.prepareCurrentContext(
                requiresFreshLocation: requiresFreshLocation,
                showsAuthorizationPrompt: showsAuthorizationPrompt,
                authorizationTimeout: authorizationTimeout,
                locationTimeout: locationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: placemarkTimeout
            )
            currentSnapshot = context.snapshot
            currentContext = context
            startupState = .ready
            return context
        } catch {
            currentContext = nil
            startupState = .failed(Self.failureCode(for: error))
            return nil
        }
    }

    func pushServerNotificationPreferenceUpdate(forceUpload: Bool = false) async {
        if let currentContext {
            await locationContextResolver.enqueueForPush(currentContext, forceUpload: forceUpload)
            return
        }

        guard let currentSnapshot else { return }
        guard let resolvedContext = try? await locationContextResolver.resolveContext(
            from: currentSnapshot,
            maximumAcceptedLocationAge: nil,
            placemarkTimeout: 8
        ) else {
            return
        }

        self.currentSnapshot = resolvedContext.snapshot
        self.currentContext = nil
        self.currentContext = resolvedContext
        await locationContextResolver.enqueueForPush(resolvedContext, forceUpload: forceUpload)
    }

    private func syncAuthorizationStatus() {
        let status = locationManager.authStatus
        let accuracy = locationManager.accuracyAuthorization
        if authorizationStatus != status {
            authorizationStatus = status
        }
        if accuracyAuthorization != accuracy {
            accuracyAuthorization = accuracy
        }
    }

    private func handleSnapshotUpdate(_ snapshot: LocationSnapshot) async {
        if currentSnapshot != snapshot {
            currentSnapshot = snapshot
        }

        guard currentScenePhase == .active, startupState == .ready else { return }
        guard shouldRefreshContext(for: snapshot) else { return }

        startupState = .resolvingContext
        contextRefreshTask?.cancel()
        contextRefreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                let context = try await self.locationContextResolver.resolveContext(
                    from: snapshot,
                    maximumAcceptedLocationAge: 5 * 60,
                    placemarkTimeout: 8
                )
                if Task.isCancelled { return }

                await MainActor.run {
                    self.currentSnapshot = context.snapshot
                    self.currentContext = nil
                    self.currentContext = context
                    self.startupState = .ready
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self.currentContext = nil
                    self.startupState = .failed(Self.failureCode(for: error))
                }
            }
        }
    }

    private func shouldRefreshContext(for snapshot: LocationSnapshot) -> Bool {
        guard let currentContext else { return true }
        guard let snapshotH3Cell = snapshot.h3Cell else { return false }
        return currentContext.h3Cell != snapshotH3Cell
    }

    private static func failureCode(for error: Error) -> String {
        guard let error = error as? LocationContextError else {
            return "location-context-error"
        }

        switch error {
        case .locationUnavailable:
            return "location-unavailable"
        case .authorizationTimeout:
            return "authorization-timeout"
        case .locationTimeout:
            return "location-timeout"
        case .missingH3Cell:
            return "location-missing-h3"
        case .missingRegionContext:
            return "location-missing-region-context"
        }
    }
}

extension LocationSession {
    @MainActor
    static var preview: LocationSession {
        let provider = LocationProvider(
            snapshotCache: NoOpLocationSnapshotCache()
        )
        let sink: LocationSink = { [provider] update in
            await provider.send(update: update)
        }
        let manager = LocationManager(onUpdate: sink)
        let nwsClient = NwsHttpClient(http: URLSessionHTTPClient())
        let metadataRepo = NwsMetadataRepo()
        let gridPointProvider = GridPointProvider(
            client: nwsClient,
            repo: metadataRepo
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: provider),
            locationProvider: provider,
            gridPointProvider: gridPointProvider,
            authorizationStatusProvider: {
                await MainActor.run { manager.authStatus }
            },
            authorizationRequester: { isActive in
                await MainActor.run {
                    manager.checkLocationAuthorization(isActive: isActive)
                }
            },
            refreshCurrentLocation: { timeout in
                await manager.refreshCurrentLocation(timeout: timeout)
            }
        )
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver
        )
        session.currentSnapshot = LocationSnapshot(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: .now,
            accuracy: 20,
            placemarkSummary: "Bennett, CO",
            h3Cell: 0x882681b485fffff
        )
        session.currentContext = LocationContext(
            snapshot: session.currentSnapshot!,
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.75,-104.44",
                latitude: 39.75,
                longitude: -104.44,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Bennett",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC005",
                fireZone: "COZ246",
                countyLabel: "Arapahoe County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        session.startupState = .ready
        return session
    }
}
