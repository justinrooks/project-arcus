//
//  LocationSession.swift
//  SkyAware
//
//  Created by Codex on 8/15/25.
//

import CoreLocation
import Observation
import OSLog
import SwiftUI
import ArcusCore

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
    private var isUITestStaticHome: Bool {
        ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1"
    }

    private let logger = Logger.locationSession
    private let locationClient: LocationClient
    private let locationManager: LocationManager
    private let locationContextResolver: any LocationContextResolving
    private let locationUploadCoordinator: any LocationUploadCoordinating
    private let durableContextCache: any DurableLocationContextCaching
    private let retentionCoordinator: HomeProjectionRetentionCoordinator

    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?
    @ObservationIgnored
    private var contextRefreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var locationResolutionGeneration: UInt64 = 0
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
        locationContextResolver: any LocationContextResolving,
        locationUploadCoordinator: any LocationUploadCoordinating,
        durableContextCache: any DurableLocationContextCaching = NoOpDurableLocationContextCache(),
        retentionCoordinator: HomeProjectionRetentionCoordinator = HomeProjectionRetentionCoordinator()
    ) {
        self.locationClient = locationClient
        self.locationManager = locationManager
        self.locationContextResolver = locationContextResolver
        self.locationUploadCoordinator = locationUploadCoordinator
        self.durableContextCache = durableContextCache
        self.retentionCoordinator = retentionCoordinator
        self.authorizationStatus = locationManager.authStatus
        self.accuracyAuthorization = locationManager.accuracyAuthorization

        locationManager.setAuthorizationChangeHandler { [weak self] status, accuracy in
            guard let self else { return }
            self.applyAuthorizationSnapshot(status: status, accuracy: accuracy, source: "authorization-change")
        }

        if isUITestStaticHome == false {
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
        uploadSource: LocationUploadSource? = nil,
        uploadReason: LocationUploadReason? = nil,
        authorizationTimeout: Double = 30,
        locationTimeout: Double = 12,
        maximumAcceptedLocationAge: TimeInterval = 5 * 60,
        placemarkTimeout: Double = 8
    ) async -> LocationContext? {
        syncAuthorizationStatus()
        invalidateDurableContextIfMoved(by: currentSnapshot)
        let generation = beginLocationResolutionAttempt()

        if authorizationStatus.isLocationAuthorized == false && showsAuthorizationPrompt == false {
            startupState = .failed("location-unavailable")
            await publishCurrentContext(nil)
            return nil
        }

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
            guard isCurrentLocationResolution(generation) else { return nil }
            await applyResolvedContext(context, generation: generation)
            guard isCurrentLocationResolution(generation) else { return nil }
            if let uploadSource {
                await locationUploadCoordinator.enqueue(
                    context,
                    source: uploadSource,
                    reason: uploadReason ?? .locationResolved,
                    forceUpload: false
                )
                guard isCurrentLocationResolution(generation) else { return nil }
            }
            startupState = .ready
            return context
        } catch {
            guard isCurrentLocationResolution(generation) else { return nil }
            startupState = .failed(Self.failureCode(for: error))
            await publishCurrentContext(nil)
            return nil
        }
    }

    func prepareScheduledBackgroundLocationContext(
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        syncAuthorizationStatus()
        let generation = beginLocationResolutionAttempt()

        let providerSnapshot = await locationClient.snapshot()
        guard isCurrentLocationResolution(generation) else { return nil }
        let latestSnapshot = reconcileCurrentSnapshot(with: providerSnapshot)

        let cachedContext = durableContextCache.load()
        let movementEvidence = movementEvidence(for: cachedContext, currentSnapshot: latestSnapshot)
        if movementEvidence != .none {
            durableContextCache.invalidate()
        }

        let policy = BackgroundLocationContextReusePolicy()
        let authorization = reuseAuthorization(for: authorizationStatus)
        let now = Date.now
        let refreshedContext = cachedContext.map {
            refreshedContextIfStable($0, snapshot: latestSnapshot)
        }
        let refreshedDecision = policy.decide(.init(
            authorization: authorization,
            cache: reuseCacheState(for: refreshedContext),
            movementEvidence: movementEvidence,
            now: now
        ))
        let reusableContext: LocationContext?
        if refreshedDecision == .reuseCachedContext {
            reusableContext = refreshedContext
        } else if let cachedContext,
                  refreshedContext?.snapshot != cachedContext.snapshot,
                  policy.decide(.init(
                      authorization: authorization,
                      cache: reuseCacheState(for: cachedContext),
                      movementEvidence: movementEvidence,
                      now: now
                  )) == .reuseCachedContext {
            reusableContext = cachedContext
        } else {
            reusableContext = nil
        }

        if let context = reusableContext {
            currentSnapshot = context.snapshot
            await applyResolvedContext(context, generation: generation)
            guard isCurrentLocationResolution(generation) else { return nil }
            if let uploadSource {
                await locationUploadCoordinator.enqueue(
                    context,
                    source: uploadSource,
                    reason: uploadReason ?? .locationResolved,
                    forceUpload: false
                )
                guard isCurrentLocationResolution(generation) else { return nil }
            }
            startupState = .ready
            return context
        }

        switch refreshedDecision {
        case .reuseCachedContext:
            return nil
        case .attemptFreshLocation:
            guard isCurrentLocationResolution(generation) else { return nil }
            return await prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                uploadSource: uploadSource,
                uploadReason: uploadReason,
                authorizationTimeout: authorizationTimeout,
                locationTimeout: locationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: placemarkTimeout
            )
        case .skipLocationDependentWork:
            guard isCurrentLocationResolution(generation) else { return nil }
            startupState = .failed("location-context-unavailable")
            await publishCurrentContext(nil)
            return nil
        }
    }

    func syncNotificationPreference(enabled: Bool) async {
        await syncPreference(forceUpload: true, reason: "notification", isSubscribedOverride: enabled)
    }

    func syncLocationSharingPreference(enabled _: Bool) async {
        await syncPreference(forceUpload: true, reason: "location-sharing")
    }

    func updateLocationSharingPreference(enabled: Bool) async {
        if enabled {
            _ = requestAlwaysAuthorizationUpgradeIfNeeded()
        }
        await syncLocationSharingPreference(enabled: enabled)
    }

    func enqueueCurrentLocationUpload(source: LocationUploadSource, reason: LocationUploadReason) async {
        guard let context = await resolveCurrentContextIfNeeded() else { return }
        await locationUploadCoordinator.enqueue(
            context,
            source: source,
            reason: reason,
            forceUpload: false
        )
    }

    func drainPendingLocationUploads() async {
        await locationUploadCoordinator.drainPendingUploads()
    }

    private func syncPreference(
        forceUpload: Bool,
        reason: String,
        isSubscribedOverride: Bool? = nil
    ) async {
        logger.notice("Queueing preference sync reason=\(reason, privacy: .public)")
        await locationUploadCoordinator.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: forceUpload,
            detail: reason,
            isSubscribedOverride: isSubscribedOverride
        )
    }

    private func resolveCurrentContextIfNeeded() async -> LocationContext? {
        if let currentContext {
            return currentContext
        }

        guard let currentSnapshot else { return nil }
        let generation = beginLocationResolutionAttempt()
        guard let resolvedContext = try? await locationContextResolver.resolveContext(
            from: currentSnapshot,
            maximumAcceptedLocationAge: nil,
            placemarkTimeout: 8
        ) else {
            return nil
        }

        guard isCurrentLocationResolution(generation) else { return nil }
        self.currentSnapshot = resolvedContext.snapshot
        await applyResolvedContext(resolvedContext, generation: generation)
        guard isCurrentLocationResolution(generation) else { return nil }
        return resolvedContext
    }

    private func syncAuthorizationStatus() {
        applyAuthorizationSnapshot(
            status: locationManager.authStatus,
            accuracy: locationManager.accuracyAuthorization,
            source: "sync"
        )
    }

    private func applyAuthorizationSnapshot(
        status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization?,
        source: String
    ) {
        let hadAuthorizationChange = authorizationStatus != status
        let hadAccuracyChange = accuracyAuthorization != accuracy
        let hadChange = hadAuthorizationChange || hadAccuracyChange

        if hadAuthorizationChange {
            authorizationStatus = status
        }
        if hadAccuracyChange {
            accuracyAuthorization = accuracy
        }

        guard hadChange else { return }

        let reliability = reliabilityState
        logger.info(
            "Location reliability updated source=\(source, privacy: .public) authorization=\(reliability.authorization.logName, privacy: .public) accuracy=\(reliability.accuracy.logName, privacy: .public) nextAction=\(reliability.nextAction.logName, privacy: .public)"
        )

        if status.isLocationAuthorized == false {
            let hadContext = currentContext != nil
            let generation = beginLocationResolutionAttempt()
            startupState = .failed("location-unavailable")
            Task { @MainActor [weak self] in
                guard let self, self.isCurrentLocationResolution(generation) else { return }
                await self.publishCurrentContext(nil)
            }
            logger.notice("Location access unavailable; currentContextReset=\(hadContext, privacy: .public)")
        }
    }

    private func handleSnapshotUpdate(_ snapshot: LocationSnapshot) async {
        if currentSnapshot != snapshot {
            currentSnapshot = snapshot
        }

        guard currentScenePhase == .active, startupState == .ready else { return }
        guard shouldRefreshContext(for: snapshot) else { return }

        let generation = beginLocationResolutionAttempt()
        startupState = .resolvingContext
        contextRefreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                let context = try await self.locationContextResolver.resolveContext(
                    from: snapshot,
                    maximumAcceptedLocationAge: 5 * 60,
                    placemarkTimeout: 8
                )
                guard Task.isCancelled == false,
                      self.isCurrentLocationResolution(generation) else { return }

                await self.applyResolvedContext(context, generation: generation)
                guard self.isCurrentLocationResolution(generation) else { return }
                self.startupState = .ready
                await self.locationUploadCoordinator.enqueue(
                    context,
                    source: .foregroundLocationChange,
                    reason: .locationChanged,
                    forceUpload: false
                )
            } catch is CancellationError {
                return
            } catch {
                guard self.isCurrentLocationResolution(generation) else { return }
                self.startupState = .failed(Self.failureCode(for: error))
                await self.publishCurrentContext(nil)
            }
        }
    }

    private func beginLocationResolutionAttempt() -> UInt64 {
        locationResolutionGeneration &+= 1
        contextRefreshTask?.cancel()
        contextRefreshTask = nil
        return locationResolutionGeneration
    }

    private func isCurrentLocationResolution(_ generation: UInt64) -> Bool {
        locationResolutionGeneration == generation
    }

    private func applyResolvedContext(_ context: LocationContext, generation: UInt64) async {
        guard isCurrentLocationResolution(generation) else { return }
        await publishCurrentContext(context)
        guard isCurrentLocationResolution(generation) else { return }
        if currentSnapshot != context.snapshot {
            currentSnapshot = context.snapshot
        }
        durableContextCache.save(context)
    }

    func publishCurrentContext(_ context: LocationContext?) async {
        await retentionCoordinator.publish(context) {
            currentContext = context
        }
    }

    private func invalidateDurableContextIfMoved(by snapshot: LocationSnapshot?) {
        guard let cachedContext = durableContextCache.load(),
              movementEvidence(for: cachedContext, currentSnapshot: snapshot) != .none else {
            return
        }
        durableContextCache.invalidate()
    }

    private func movementEvidence(
        for cachedContext: LocationContext?,
        currentSnapshot: LocationSnapshot?
    ) -> BackgroundLocationContextReusePolicy.MovementEvidence {
        guard let cachedContext, let currentSnapshot,
              currentSnapshot.timestamp > cachedContext.snapshot.timestamp else {
            return .none
        }
        guard currentSnapshot.h3Cell == cachedContext.h3Cell else {
            return .significantLocationChange
        }
        return .none
    }

    private func reconcileCurrentSnapshot(with providerSnapshot: LocationSnapshot?) -> LocationSnapshot? {
        guard let providerSnapshot else { return currentSnapshot }
        guard let currentSnapshot, currentSnapshot.timestamp > providerSnapshot.timestamp else {
            currentSnapshot = providerSnapshot
            return providerSnapshot
        }
        return currentSnapshot
    }

    private func refreshedContextIfStable(_ context: LocationContext, snapshot: LocationSnapshot?) -> LocationContext {
        guard let snapshot,
              snapshot.timestamp >= context.snapshot.timestamp,
              snapshot.h3Cell == context.h3Cell else {
            return context
        }
        if snapshot.timestamp == context.snapshot.timestamp {
            guard snapshot.coordinates.latitude == context.snapshot.coordinates.latitude,
                  snapshot.coordinates.longitude == context.snapshot.coordinates.longitude,
                  context.snapshot.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
                  let name = snapshot.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
                  name.isEmpty == false else {
                return context
            }
            var enrichedSnapshot = context.snapshot
            enrichedSnapshot.placemarkSummary = name
            return LocationContext(snapshot: enrichedSnapshot, h3Cell: context.h3Cell, grid: context.grid)
        }
        return LocationContext(snapshot: snapshot, h3Cell: context.h3Cell, grid: context.grid)
    }

    private func reuseCacheState(
        for context: LocationContext?
    ) -> BackgroundLocationContextReusePolicy.CacheState {
        guard let context else { return .missing }
        return .available(.init(
            coordinatesAreValid: CLLocationCoordinate2DIsValid(context.snapshot.coordinates),
            timestamp: context.snapshot.timestamp,
            horizontalAccuracy: context.snapshot.accuracy,
            isComplete: context.grid.countyCode?.isEmpty == false && context.grid.fireZone?.isEmpty == false
        ))
    }

    private func reuseAuthorization(for status: CLAuthorizationStatus) -> BackgroundLocationContextReusePolicy.Authorization {
        switch status {
        case .authorizedAlways: .always
        case .authorizedWhenInUse: .whenInUse
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unknown
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
            locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
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
