//
//  WatchGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/2/26.
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
//        guard let day = event.payload["localDay"] as? String else {
//            logger.debug("Gate missing 'localDay' parameter")
//            return false
//        }
        
        guard let watchId = event.payload["watchId"] as? String else {
            logger.debug("Gate missing 'watchId' parameter")
            return false
        }
  
        let last = await store.lastStamp()
        guard last != event.key else {
        logger.debug("Already sent a notification for watch \(watchId, privacy: .public) today")
            return false
        }
        
        logger.debug("Updating the store stamp")
        await store.setLastStamp(event.key)
        
        logger.notice("Passed the gate")
        return true
    }
}

struct DefaultWatchStore: NotificationStateStoring {
    private let key = "skyaware.lastWatchNotifyLocalDay"
    
    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
