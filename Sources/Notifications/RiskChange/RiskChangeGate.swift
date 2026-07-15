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

    private struct Pending: Codable {
        let delivery: Delivery
        let projectionKey: String
        let registrationOrder: Int64
        let registeredAt: Date
    }

    private struct Tombstone: Codable {
        let deliveredAt: Date
    }

    private struct State: Codable {
        var pending: [String: Pending] = [:]
        var delivered: [String: Tombstone] = [:]
        var nextRegistrationOrder: Int64 = 0

        private enum CodingKeys: String, CodingKey {
            case pending, delivered, nextRegistrationOrder
        }

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pending = try container.decodeIfPresent([String: Pending].self, forKey: .pending) ?? [:]
            delivered = try container.decodeIfPresent([String: Tombstone].self, forKey: .delivered) ?? [:]
            nextRegistrationOrder = try container.decodeIfPresent(Int64.self, forKey: .nextRegistrationOrder) ?? 0
        }
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
        message: (title: String, body: String, subtitle: String),
        now: Date = .now
    ) async {
        await loadIfNeeded()
        guard let change = event.payload["change"] as? RiskProfileChange else { return }
        var didChange = purgeExpired(now: now)
        guard state.pending[event.key] == nil, state.delivered[event.key] == nil else {
            if didChange { await persist() }
            return
        }

        for key in state.pending.keys where
            state.pending[key]?.projectionKey == change.projectionKey && inFlightEventKeys.contains(key) == false {
            state.pending.removeValue(forKey: key)
            didChange = true
        }

        state.nextRegistrationOrder += 1
        state.pending[event.key] = Pending(
            delivery: Delivery(eventKey: event.key, title: message.title, body: message.body, subtitle: message.subtitle),
            projectionKey: change.projectionKey,
            registrationOrder: state.nextRegistrationOrder,
            registeredAt: now
        )
        await persist()
    }

    /// Claims one pending occurrence. The claim is recorded before the sender is awaited.
    func claim(preferredEventKey: String?, isEnabled: Bool, now: Date = .now) async -> Delivery? {
        await loadIfNeeded()
        if purgeExpired(now: now) { await persist() }
        guard isEnabled else { return nil }

        let eventKey: String?
        if let preferredEventKey {
            guard state.pending[preferredEventKey] != nil,
                  inFlightEventKeys.contains(preferredEventKey) == false else { return nil }
            eventKey = preferredEventKey
        } else {
            eventKey = state.pending.values
                .filter { inFlightEventKeys.contains($0.delivery.eventKey) == false }
                .sorted {
                    ($0.registrationOrder, $0.delivery.eventKey) < ($1.registrationOrder, $1.delivery.eventKey)
                }
                .first?.delivery.eventKey
        }
        guard let eventKey, inFlightEventKeys.insert(eventKey).inserted else { return nil }
        return state.pending[eventKey]?.delivery
    }

    func finish(_ delivery: Delivery, didSchedule: Bool, now: Date = .now) async {
        guard let pending = state.pending[delivery.eventKey] else {
            inFlightEventKeys.remove(delivery.eventKey)
            return
        }

        if didSchedule {
            state.pending.removeValue(forKey: delivery.eventKey)
            state.delivered[delivery.eventKey] = Tombstone(deliveredAt: now)
            trimDeliveredTombstones()
            await persist()
        } else {
            let hasNewerPending = state.pending.values.contains {
                $0.projectionKey == pending.projectionKey && $0.registrationOrder > pending.registrationOrder
            }
            if hasNewerPending || now.timeIntervalSince(pending.registeredAt) > Self.pendingLifetime {
                state.pending.removeValue(forKey: delivery.eventKey)
                await persist()
            }
        }
        inFlightEventKeys.remove(delivery.eventKey)
    }

    private static let pendingLifetime: TimeInterval = 24 * 60 * 60

    private func purgeExpired(now: Date) -> Bool {
        let expiredKeys: [String] = state.pending.compactMap { entry in
            let (key, pending) = entry
            guard inFlightEventKeys.contains(key) == false,
                  now.timeIntervalSince(pending.registeredAt) > Self.pendingLifetime else { return nil }
            return key
        }
        expiredKeys.forEach { state.pending.removeValue(forKey: $0) }
        return expiredKeys.isEmpty == false
    }

    private func trimDeliveredTombstones() {
        let excess = state.delivered.count - 128
        guard excess > 0 else { return }
        let oldest = state.delivered.sorted { lhs, rhs in
            (lhs.value.deliveredAt, lhs.key) < (rhs.value.deliveredAt, rhs.key)
        }.prefix(excess)
        oldest.forEach { state.delivered.removeValue(forKey: $0.key) }
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
