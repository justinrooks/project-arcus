import Foundation
import OSLog

/// App-owned derived cache. App Intents execute in the host app; no shared-container entitlement is needed.
/// Only the app's accepted-state publisher writes this file.
struct WeatherAwarenessSnapshotStore: Sendable {
    enum StoreError: Error { case snapshotTooLarge }
    static let live = WeatherAwarenessSnapshotStore(
        directoryURL: URL.applicationSupportDirectory.appending(path: "WeatherAwareness", directoryHint: .isDirectory)
    )
    static let maximumBytes = 256 * 1_024
    let directoryURL: URL

    var fileURL: URL { directoryURL.appending(path: "accepted-awareness-v1.json") }

    func write(_ snapshot: WeatherAwarenessSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        guard data.count <= Self.maximumBytes else { throw StoreError.snapshotTooLarge }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    /// No dependency container, SwiftData graph, authorization, or refresh is constructed by a cold read.
    func read(expectedProjectionKey: String? = nil, now: Date = .now) async -> WeatherAwarenessResult {
        await Task.detached {
            let data: Data
            do {
                let handle = try FileHandle(forReadingFrom: fileURL)
                defer { try? handle.close() }
                data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
            } catch {
                let error = error as NSError
                if error.domain == NSCocoaErrorDomain,
                   error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError {
                    return .unavailable(.noCache)
                }
                return .unavailable(.readFailure)
            }
            guard data.count <= Self.maximumBytes,
                  let snapshot = try? JSONDecoder().decode(WeatherAwarenessSnapshot.self, from: data) else {
                return .unavailable(.corruptCache)
            }
            return .select(snapshot, expectedProjectionKey: expectedProjectionKey, now: now)
        }.value
    }
}

/// File work runs outside the SwiftData executor (which may use the main queue).
/// Revisions are reserved by HomeProjectionStore before suspension, not derived from wall-clock timestamps.
actor WeatherAwarenessSnapshotPublisher {
    private let store: WeatherAwarenessSnapshotStore
    private var newestRevision: UInt64 = 0

    init(store: WeatherAwarenessSnapshotStore) { self.store = store }

    func publish(_ snapshot: WeatherAwarenessSnapshot, revision: UInt64) {
        guard revision > newestRevision else { return }
        newestRevision = revision
        // Even a failed newer write fences older callbacks; never roll the file back to an older context.
        do {
            try store.write(snapshot)
        } catch {
            Logger.appHomeRefresh.error("Accepted awareness snapshot write failed")
        }
    }
}
