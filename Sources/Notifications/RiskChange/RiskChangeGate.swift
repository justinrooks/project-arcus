//
//  RiskChangeGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/15/26.
//

import Foundation
import OSLog

struct RiskChangeGate: NotificationGating {
    private let logger = Logger.notificationsRiskChangeGate
    private let store: NotificationStateStoring

    init(store: NotificationStateStoring) {
        self.store = store
    }

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking risk change notification gate")

        guard let change = event.payload["change"] as? RiskProfileChange else {
            logger.debug("Gate missing 'change' parameter")
            return false
        }

        var state = Self.decode(await store.lastStamp())
        let projectionKey = change.projectionKey
        let currentFingerprint = change.currentFingerprint

        guard state[projectionKey] != currentFingerprint else {
            logger.debug("Already sent a risk change notification for projection \(projectionKey, privacy: .public)")
            return false
        }

        state[projectionKey] = currentFingerprint
        await store.setLastStamp(Self.encode(state))

        logger.notice("Passed the gate")
        return true
    }

    private static func decode(_ stamp: String?) -> [String: String] {
        guard let stamp, stamp.isEmpty == false, let data = stamp.data(using: .utf8) else {
            return [:]
        }

        guard let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return decoded
    }

    private static func encode(_ state: [String: String]) -> String {
        guard let data = try? JSONEncoder.sortedKeys.encode(state) else {
            return "{}"
        }

        return String(decoding: data, as: UTF8.self)
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
    private let key = "skyaware.lastRiskChangeNotifyCurrentFingerprintByProjectionKey"

    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }

    func setLastStamp(_ stamp: String) async {
        UserDefaults.standard.set(stamp, forKey: key)
    }
}
