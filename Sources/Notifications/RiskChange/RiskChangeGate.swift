//
//  RiskChangeGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/15/26.
//

import Foundation
import OSLog

/// The single serialized owner of durable risk-change delivery state.
actor RiskChangeGate {
    struct Delivery: Sendable, Codable, Equatable {
        let eventKey: String
        let title: String
        let body: String
        let subtitle: String
    }

    private struct State: Codable {
        var pending: [String: Delivery] = [:]
        var deliveredEventKeys = Set<String>()
    }

    private let logger = Logger.notificationsRiskChangeGate
    private let store: NotificationStateStoring
    private var state = State()
    private var isLoaded = false
    private var loadingTask: Task<State, Never>?
    private var inFlightEventKeys = Set<String>()
    private var persistenceTask: Task<Void, Never>?

    init(store: NotificationStateStoring) {
        self.store = store
    }

    func register(
        event: NotificationEvent,
        message: (title: String, body: String, subtitle: String)
    ) async {
        await loadIfNeeded()
        guard state.pending[event.key] == nil, state.deliveredEventKeys.contains(event.key) == false else { return }

        state.pending[event.key] = Delivery(
            eventKey: event.key,
            title: message.title,
            body: message.body,
            subtitle: message.subtitle
        )
        await persist()
    }

    /// Claims one pending occurrence. The claim is recorded before the sender is awaited.
    func claim(preferredEventKey: String?, isEnabled: Bool) async -> Delivery? {
        await loadIfNeeded()
        guard isEnabled else { return nil }

        let eventKey = preferredEventKey.flatMap { state.pending[$0] == nil ? nil : $0 }
            ?? state.pending.keys.sorted().first { inFlightEventKeys.contains($0) == false }
        guard let eventKey, inFlightEventKeys.insert(eventKey).inserted else { return nil }
        return state.pending[eventKey]
    }

    func finish(_ delivery: Delivery, didSchedule: Bool) async {
        if didSchedule {
            state.pending.removeValue(forKey: delivery.eventKey)
            state.deliveredEventKeys.insert(delivery.eventKey)
            await persist()
        }
        inFlightEventKeys.remove(delivery.eventKey)
    }

    private func loadIfNeeded() async {
        guard isLoaded == false else { return }

        let task: Task<State, Never>
        if let loadingTask {
            task = loadingTask
        } else {
            let store = self.store
            task = Task {
                guard
                    let stamp = await store.lastStamp(),
                    let data = stamp.data(using: .utf8),
                    let decoded = try? JSONDecoder().decode(State.self, from: data)
                else {
                    return State()
                }
                return decoded
            }
            loadingTask = task
        }

        let loadedState = await task.value
        guard isLoaded == false else { return }
        state = loadedState
        isLoaded = true
        loadingTask = nil
    }

    private func persist() async {
        guard let data = try? JSONEncoder.sortedKeys.encode(state) else { return }
        let stamp = String(decoding: data, as: UTF8.self)
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

private extension JSONEncoder {
    static var sortedKeys: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

struct DefaultRiskChangeStore: NotificationStateStoring {
    private let key = "skyaware.riskChangeDeliveryState"

    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }

    func setLastStamp(_ stamp: String) async {
        UserDefaults.standard.set(stamp, forKey: key)
    }
}
