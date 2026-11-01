import ArcusCore
import CoreLocation
import UIKit

/// Process-lifetime location authority, available before the weather store can open.
@MainActor
final class LocationPresenceRuntime {
    static let shared = LocationPresenceRuntime()

    let provider: LocationProvider
    let pusher: LocationSnapshotPusher
    let manager: LocationManager

    private init() {
        let provider = LocationProvider(snapshotCache: LocationSnapshotCache())
        let http = URLSessionHTTPClient(observer: LastGlobalSuccessHTTPObserver(), urlCache: .skyAwareCache)
        let baseURL = ArcusSignalConfiguration.baseURL()
        let pusher = LocationSnapshotPusher(
            locationUploader: HTTPLocationSnapshotUploader(
                baseURL: baseURL, http: http, protocolVersion: .geographyInvalidatingV4
            ),
            preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: baseURL, http: http)
        )
        self.provider = provider
        self.pusher = pusher
        manager = LocationManager(
            onUpdate: { await provider.send(update: $0) },
            onBackgroundUpdate: { update in
                await Self.acceptBackgroundUpdate(
                    update, provider: provider, enqueuer: BackgroundPresenceEnqueuer(pusher: pusher)
                )
            },
            drainBackgroundPresence: { await pusher.drainPendingUploads() }
        )
    }

    func restoreBackgroundMonitoring() {
        manager.updateMode(for: .background)
    }

    /// No weather context or Home ingestion is needed for admission.
    static func acceptBackgroundUpdate(
        _ update: LocationUpdate,
        provider: LocationProvider,
        enqueuer: any LocationPresenceEnqueuing,
        now: Date = .now
    ) async -> LocationAcceptance {
        let age = now.timeIntervalSince(update.timestamp)
        guard age >= 0, age <= 5 * 60 else { return .rejected }
        let acceptance = await provider.send(update: update)
        guard acceptance == .accepted else { return acceptance }
        // A newer accepted delivery supersedes this one if acceptance interleaved.
        guard let snapshot = await provider.snapshot(), snapshot.timestamp == update.timestamp else {
            return .redundant
        }
        _ = await enqueuer.enqueuePresence(snapshot, source: .backgroundLocationChange, reason: .locationChanged)
        // Location sharing consent/storage availability must not disable local watch/risk ownership.
        return .accepted
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
            UIApplication.shared.beginBackgroundTask(withName: "Location presence") {
                Task { @MainActor in expire() }
            }
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
