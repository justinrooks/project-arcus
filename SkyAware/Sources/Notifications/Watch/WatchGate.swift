//
//  WatchGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/2/26.
//

import Foundation
import OSLog

struct WatchGate: NotificationGate {
    private let logger = Logger.watchGate
    private let store: NotificationStateStore
    
    init(store: NotificationStateStore) {
        self.store = store
    }

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking watch notification gate")
        guard let day = event.payload["localDay"] as? String else {
            logger.debug("Gate missing 'localDay' parameter")
            return false
        }
        
        guard let watchId = event.payload["watchId"] as? String else {
            logger.debug("Gate missing 'watchId' parameter")
            return false
        }
  
        let last = await store.lastStamp()
        guard last != event.key else {
            logger.debug("Already sent a notification for watch \(watchId) today")
            return false
        }
        
        logger.debug("Updating the store stamp")
        await store.setLastStamp(event.key)
        
        logger.info("Passed the gate")
        return true
    }
}

struct DefaultWatchStore: NotificationStateStore {
    private let key = "skyaware.lastWatchNotifyLocalDay"
    
    init() {}
    
    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
