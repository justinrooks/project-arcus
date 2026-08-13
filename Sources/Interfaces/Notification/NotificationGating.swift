//
//  NotificationGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationGating: Sendable {
    func allow(_ event: NotificationEvent, now: Date) async -> Bool
    func finish(_ event: NotificationEvent, didSchedule: Bool) async
}

extension NotificationGating {
    func finish(_ event: NotificationEvent, didSchedule: Bool) async {}
}

actor NotificationClaimState {
    enum Retention: Sendable {
        case latest
        case all
    }

    private let store: NotificationStateStoring
    private let retention: Retention
    private var delivered = Set<String>()
    private var inFlight = Set<String>()
    private var isLoaded = false
    private var loadingTask: Task<String?, Never>?
    private var persistenceTask: Task<Void, Never>?

    init(store: NotificationStateStoring, retention: Retention) {
        self.store = store
        self.retention = retention
    }

    func claim(_ identity: String) async -> Bool {
        await loadIfNeeded()
        guard delivered.contains(identity) == false else { return false }
        return inFlight.insert(identity).inserted
    }

    func finish(_ identity: String, didSchedule: Bool) async {
        guard inFlight.remove(identity) != nil, didSchedule else { return }

        switch retention {
        case .latest:
            delivered = [identity]
        case .all:
            delivered.insert(identity)
        }
        await persist()
    }

    private func loadIfNeeded() async {
        guard isLoaded == false else { return }

        let task: Task<String?, Never>
        if let loadingTask {
            task = loadingTask
        } else {
            let store = self.store
            task = Task { await store.lastStamp() }
            loadingTask = task
        }

        let stamp = await task.value
        guard isLoaded == false else { return }
        if let stamp, stamp.isEmpty == false {
            switch retention {
            case .latest:
                delivered = [stamp]
            case .all:
                delivered = Set(stamp.split(separator: "\n").map(String.init))
            }
        }
        isLoaded = true
        loadingTask = nil
    }

    private func persist() async {
        let stamp: String
        switch retention {
        case .latest:
            stamp = delivered.first ?? ""
        case .all:
            stamp = delivered.sorted().joined(separator: "\n")
        }

        let previousTask = persistenceTask
        let store = self.store
        let task = Task {
            await previousTask?.value
            await store.setLastStamp(stamp)
        }
        persistenceTask = task
        await task.value
    }
}
