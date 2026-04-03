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
    private let store: NotificationStateStoring

    init(store: NotificationStateStoring) {
        self.store = store
    }

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking watch notification gate")

        guard let watchId = event.payload["watchId"] as? String, watchId.isEmpty == false else {
            logger.debug("Gate missing 'watchId' parameter")
            return false
        }

        var notifiedWatchIDs = Self.decode(await store.lastStamp())
        guard notifiedWatchIDs.contains(watchId) == false else {
            logger.debug("Already sent a notification for watch \(watchId, privacy: .public)")
            return false
        }

        notifiedWatchIDs.insert(watchId)
        await store.setLastStamp(Self.encode(notifiedWatchIDs))
        logger.notice("Passed the gate")
        return true
    }

    private static func decode(_ stamp: String?) -> Set<String> {
        guard let stamp, stamp.isEmpty == false else { return [] }
        return Set(stamp.split(separator: "\n").map(String.init))
    }

    private static func encode(_ watchIDs: Set<String>) -> String {
        watchIDs.sorted().joined(separator: "\n")
    }
}

struct DefaultWatchStore: NotificationStateStoring {
    private let key = "skyaware.lastWatchNotifyID"

    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
