//
//  WatchGate.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

struct WatchGate: NotificationGating {
    private let logger = Logger.notificationsWatchGate
    private let claims: NotificationClaimState

    init(store: NotificationStateStoring) {
        claims = NotificationClaimState(store: store, retention: .all)
    }

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking watch notification gate")

        guard let watchId = event.payload["watchId"] as? String, watchId.isEmpty == false else {
            logger.debug("Gate missing 'watchId' parameter")
            return false
        }

        guard await claims.claim(watchId) else {
            logger.debug("Already sent a notification for watch \(watchId, privacy: .public)")
            return false
        }

        logger.notice("Passed the gate")
        return true
    }

    func finish(_ event: NotificationEvent, didSchedule: Bool) async {
        guard let watchId = event.payload["watchId"] as? String, watchId.isEmpty == false else { return }
        await claims.finish(watchId, didSchedule: didSchedule)
    }
}

struct DefaultWatchStore: NotificationStateStoring {
    private let key = "skyaware.lastWatchNotifyID"

    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
