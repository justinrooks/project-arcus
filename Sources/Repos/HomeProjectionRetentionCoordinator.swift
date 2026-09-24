//
//  HomeProjectionRetentionCoordinator.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftData

final class HomeProjectionRetentionCoordinator: @unchecked Sendable {
    static let shared = HomeProjectionRetentionCoordinator()
    private static let registry = StoreRegistry()

    private final class StoreRegistry: @unchecked Sendable {
        private let lock = NSLock()
        private var coordinators: [String: HomeProjectionRetentionCoordinator] = [:]

        func coordinator(for storePath: String) -> HomeProjectionRetentionCoordinator {
            lock.lock()
            defer { lock.unlock() }
            if let coordinator = coordinators[storePath] { return coordinator }
            let coordinator = HomeProjectionRetentionCoordinator()
            coordinators[storePath] = coordinator
            return coordinator
        }
    }

    private let stateLock = NSLock()
    private var hasLease = false
    private var leaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var activeProjectionKey: String?

    static func forStore(_ modelContainer: ModelContainer) -> HomeProjectionRetentionCoordinator {
        let storePath = modelContainer.configurations.first?.url.standardizedFileURL.path ?? "default"
        return registry.coordinator(for: storePath)
    }

    func acquire() async {
        await withCheckedContinuation { continuation in
            stateLock.lock()
            if hasLease {
                leaseWaiters.append(continuation)
                stateLock.unlock()
            } else {
                hasLease = true
                stateLock.unlock()
                continuation.resume()
            }
        }
    }

    func release() {
        stateLock.lock()
        let nextWaiter = leaseWaiters.isEmpty ? nil : leaseWaiters.removeFirst()
        if nextWaiter == nil { hasLease = false }
        stateLock.unlock()
        nextWaiter?.resume()
    }

    func currentActiveProjectionKey() -> String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeProjectionKey
    }

    func waitingPublisherCount() -> Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return leaseWaiters.count
    }

    func setActiveProjectionKey(_ key: String?) {
        stateLock.lock()
        activeProjectionKey = key
        stateLock.unlock()
    }

    @MainActor
    func publish(_ context: LocationContext?, updating update: () -> Void) async {
        guard Task.isCancelled == false else { return }
        // Publish observable location state before waiting on background cache maintenance.
        update()
        await acquire()
        defer { release() }
        guard Task.isCancelled == false else { return }
        setActiveProjectionKey(context.map(HomeProjection.projectionKey(for:)))
    }
}
