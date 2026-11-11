import ArcusCore
import CoreLocation
import UIKit
import OSLog

/// Process-lifetime location authority, available before the weather store can open.
@MainActor
final class LocationPresenceRuntime {
    static let shared = LocationPresenceRuntime()

    let provider: LocationProvider
    let pusher: LocationSnapshotPusher
    let manager: LocationManager
    let metadataRepo: NwsMetadataRepo
    let gridProvider: GridPointProvider

    private init() {
        let provider = LocationProvider(snapshotCache: LocationSnapshotCache())
        let http = URLSessionHTTPClient(observer: LastGlobalSuccessHTTPObserver(), urlCache: .skyAwareCache)
        let metadataRepo = NwsMetadataRepo()
        let gridProvider = GridPointProvider(client: NwsHttpClient(http: http), repo: metadataRepo)
        self.metadataRepo = metadataRepo
        self.gridProvider = gridProvider
        let baseURL = ArcusSignalConfiguration.baseURL()
        let pusher = LocationSnapshotPusher(
            locationUploader: HTTPLocationSnapshotUploader(
                baseURL: baseURL, http: http, protocolVersion: .geographyInvalidatingV4
            ),
            preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: baseURL, http: http)
        )
        self.provider = provider
        self.pusher = pusher
        let admission = LocationPresenceAdmission(provider: provider, foreground: ForegroundPresenceEnqueuer(pusher: pusher),
            background: BackgroundPresenceEnqueuer(pusher: pusher),
            evidenceCutoff: { pusher.minimumLocationObservationTimestamp },
            onObservation: { snapshot, source in
                guard pusher.isLocationSharingEnabled else { return }
                Task {
                    guard let h3 = snapshot.h3Cell,
                          let grid = await gridProvider.resolveGridPoint(for: snapshot.coordinates,
                                                                        capturedAt: snapshot.timestamp),
                          !Task.isCancelled,
                          let current = await provider.snapshot(), current.hasSameObservation(as: snapshot) else { return }
                    _ = await pusher.enqueueEnrichment(.init(snapshot: snapshot, h3Cell: h3, grid: grid),
                                                       source: source, reason: .locationChanged)
                }
            })
        manager = LocationManager(
            onUpdate: { await admission.accept($0, source: .foregroundLocationChange).acceptance },
            onForegroundActivation: { isEligible in
                await admission.retryForegroundAdmission(isEligible: isEligible)
                if isEligible() { await pusher.drainPendingUploads() }
            },
            onBackgroundUpdate: { update in
                await admission.accept(update, source: .backgroundLocationChange).acceptance
            },
            drainBackgroundPresence: { await pusher.drainPendingUploads() }
        )
    }

    func restoreBackgroundMonitoring() {
        manager.updateMode(for: .background)
    }

    /// Uses only persisted intent; an OS execution opportunity is not a new observation.
    static func drainScheduledPresence(
        using drainer: any PendingLocationUploadDraining,
        protectedDataAvailable: @MainActor @Sendable () -> Bool = { UIApplication.shared.isProtectedDataAvailable },
        budget: PendingLocationUploadDrainBudget = .init(uploadQuota: 1, deadline: .now + .seconds(5)),
        waitForDeadline: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
            try await ContinuousClock().sleep(until: $0)
        }
    ) async -> PendingLocationUploadDrainOutcome {
        guard !Task.isCancelled, protectedDataAvailable(), ContinuousClock().now < budget.deadline else {
            return .remaining
        }
        return await withTaskGroup(of: PendingLocationUploadDrainOutcome.self) { group in
            group.addTask {
                await InstallationEnrollmentCoordinator.$requiresExistingEnrollment.withValue(true) {
                    await drainer.drainPendingUploads(using: budget)
                }
            }
            group.addTask {
                try? await waitForDeadline(budget.deadline)
                return .remaining
            }
            let outcome = await group.next() ?? .remaining
            group.cancelAll()
            return outcome
        }
    }

    /// No weather context or Home ingestion is needed for admission.
    static func acceptBackgroundUpdate(
        _ update: LocationUpdate,
        provider: LocationProvider,
        enqueuer: any LocationPresenceEnqueuing,
        now: Date = .now
    ) async -> LocationAcceptance {
        await LocationPresenceAdmission(provider: provider, foreground: enqueuer, background: enqueuer,
            now: { now }).accept(update, source: .backgroundLocationChange).acceptance
    }
}

/// One process-owned cadence authority. The pusher remains the durable consent authority.
@MainActor
final class LocationPresenceAdmission {
    enum Retention: Equatable { case notAttempted, retained, failed }
    struct Result {
        let acceptance: LocationAcceptance
        let retention: Retention
    }
    private let logger = Logger.locationPushPusher
    private let provider: LocationProvider
    private let foreground: any LocationPresenceEnqueuing
    private let background: any LocationPresenceEnqueuing
    private let now: @MainActor @Sendable () -> Date
    private var attempt: (snapshot: LocationSnapshot, at: Date, failed: Bool)?
    private var inFlight: Set<Date> = []
    private let evidenceCutoff: @MainActor @Sendable () -> Date?
    private var previousCutoff: Date?
    private let onObservation: @MainActor @Sendable (LocationSnapshot, LocationUploadSource) -> Void

    init(provider: LocationProvider, foreground: any LocationPresenceEnqueuing,
         background: any LocationPresenceEnqueuing,
         now: @escaping @MainActor @Sendable () -> Date = { .now },
         evidenceCutoff: @escaping @MainActor @Sendable () -> Date? = { nil },
         onObservation: @escaping @MainActor @Sendable (LocationSnapshot, LocationUploadSource) -> Void = { _, _ in }) {
        self.provider = provider
        self.foreground = foreground
        self.background = background
        self.now = now
        self.evidenceCutoff = evidenceCutoff
        self.onObservation = onObservation
    }

    func accept(_ update: LocationUpdate, source: LocationUploadSource) async -> Result {
        if source == .backgroundLocationChange {
            let age = now().timeIntervalSince(update.timestamp)
            guard age >= 0, age <= 300 else {
                logger.debug("Presence stage=rejected reason=background_freshness")
                return .init(acceptance: .rejected, retention: .notAttempted)
            }
        }
        let acceptance = await provider.send(update: update)
        guard acceptance == .accepted || (acceptance == .redundant && attempt?.failed == true),
              let snapshot = await provider.snapshot(),
              snapshot.timestamp == update.timestamp || (acceptance == .redundant && attempt?.failed == true) else {
            return .init(acceptance: acceptance, retention: .notAttempted)
        }
        let retention = await admit(snapshot, source: source)
        if retention != .failed, evidenceCutoff().map({ snapshot.timestamp >= $0 }) ?? true {
            onObservation(snapshot, source)
        }
        return .init(acceptance: acceptance, retention: retention)
    }

    func retryForegroundAdmission(
        isEligible: @escaping @MainActor @Sendable () -> Bool = { true }
    ) async {
        guard isEligible(), let snapshot = await provider.snapshot(), isEligible() else { return }
        let retention = await admit(snapshot, source: .foregroundLocationChange, isEligible: isEligible)
        if isEligible(), retention != .failed,
           evidenceCutoff().map({ snapshot.timestamp >= $0 }) ?? true {
            onObservation(snapshot, .foregroundLocationChange)
        }
    }

    func admit(_ snapshot: LocationSnapshot, source: LocationUploadSource,
               isEligible: (@MainActor @Sendable () -> Bool)? = nil) async -> Retention {
        var reason = "ineligible_execution"
        defer {
            logger.debug("Presence stage=admission_result reason=\(reason, privacy: .public) source=\(source.rawValue, privacy: .public)")
        }
        guard isEligible?() ?? true else { return .notAttempted }
        let time = now()
        let cutoff = evidenceCutoff()
        if cutoff != previousCutoff { attempt = nil; previousCutoff = cutoff }
        reason = "evidence_cutoff"
        guard cutoff.map({ snapshot.timestamp >= $0 }) ?? true else { return .notAttempted }
        reason = "missing_spatial_identity_or_in_flight"
        guard snapshot.h3Cell != nil, !inFlight.contains(snapshot.timestamp) else { return .notAttempted }
        if let previous = attempt {
            reason = "older_than_admission"
            guard snapshot.timestamp >= previous.snapshot.timestamp else { return .notAttempted }
            if snapshot.h3Cell == previous.snapshot.h3Cell {
                let elapsed = time.timeIntervalSince(previous.at)
                reason = previous.failed ? "retry_cadence" : "same_cell_cadence"
                guard previous.failed ? elapsed >= 30 :
                    (snapshot.timestamp > previous.snapshot.timestamp && elapsed >= 300) else { return .notAttempted }
            }
        }
        attempt = (snapshot, time, false)
        inFlight.insert(snapshot.timestamp)
        defer { inFlight.remove(snapshot.timestamp) }
        let enqueuer = source == .backgroundLocationChange ? background : foreground
        let retained: Bool
        if source == .foregroundLocationChange, let isEligible {
            retained = await enqueuer.enqueueForegroundPresence(snapshot, isEligible: isEligible)
        } else {
            retained = await enqueuer.enqueuePresence(snapshot, source: source, reason: .locationChanged)
        }
        if attempt?.snapshot.hasSameObservation(as: snapshot) == true, attempt?.at == time {
            attempt?.failed = !retained
        }
        reason = retained ? "durably_retained" : "retention_failed"
        return retained ? .retained : .failed
    }
}

struct ForegroundPresenceEnqueuer: LocationPresenceEnqueuing {
    let pusher: LocationSnapshotPusher
    func enqueuePresence(_ observation: LocationSnapshot, source: LocationUploadSource,
                         reason: LocationUploadReason) async -> Bool {
        let retained = await pusher.retainPresence(observation, source: source)
        if retained { Task { await pusher.drainPendingUploads() } }
        return retained
    }
    /// Activation owns its drain task so phase retirement cancels preparation and transport.
    func enqueueForegroundPresence(_ observation: LocationSnapshot,
        isEligible: @escaping @MainActor @Sendable () -> Bool) async -> Bool {
        guard await isEligible() else { return false }
        return await pusher.retainPresence(observation, source: .foregroundLocationChange)
    }
}

struct BackgroundPresenceEnqueuer: LocationPresenceEnqueuing {
    let pusher: LocationSnapshotPusher
    func enqueuePresence(_ observation: LocationSnapshot, source: LocationUploadSource,
                         reason: LocationUploadReason) async -> Bool {
        await pusher.retainBackgroundPresence(observation)
    }
}

/// Bounds the delivery to the OS grant. Expiration cancels work; the outbox retains intent.
@MainActor
final class BackgroundPresenceDelivery {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var task: Task<LocationAcceptance, Never>?
    private var expired = false
    private let end: @MainActor (UIBackgroundTaskIdentifier) -> Void

    private init(end: @escaping @MainActor (UIBackgroundTaskIdentifier) -> Void) { self.end = end }

    static func run(
        begin: @MainActor (@escaping @MainActor @Sendable () -> Void) -> UIBackgroundTaskIdentifier = { expire in
            UIApplication.shared.beginBackgroundTask(withName: "Location presence", expirationHandler: expire)
        },
        end: @escaping @MainActor (UIBackgroundTaskIdentifier) -> Void = { UIApplication.shared.endBackgroundTask($0) },
        operation: @escaping @Sendable () async -> LocationAcceptance
    ) async -> LocationAcceptance {
        let delivery = BackgroundPresenceDelivery(end: end)
        delivery.identifier = begin {
            delivery.expired = true
            delivery.task?.cancel()
            delivery.finish()
        }
        let task = Task {
            let result = await operation()
            return Task.isCancelled ? LocationAcceptance.rejected : result
        }
        delivery.task = task
        if delivery.expired { task.cancel(); delivery.finish() }
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        delivery.finish()
        return result
    }

    private func finish() {
        guard identifier != .invalid else { return }
        end(identifier)
        identifier = .invalid
    }
}
