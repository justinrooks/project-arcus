//
//  MorningGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct MorningGate: NotificationGate {
    private let logger = Logger.gate
    private let store: MorningStateStore
    
    init(store: MorningStateStore) {
        self.store = store
    }
    
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking morning notification gate")
        guard let day = event.payload["localDay"] as? String else {
            logger.debug("Gate missing 'localDay' parameter")
            return false
        }
        
        let last = await store.lastMorningStamp()
        guard last != day else {
            logger.debug("Already sent a notification for today")
            return false
        }
        
        logger.debug("Updating the morning store stamp")
        await store.setLastMorningStamp(day)
        
        logger.info("Passed the gate")
        return true
    }
}

struct DefaultStore: MorningStateStore {
    private let key = "skyaware.lastMorningNotifyLocalDay"
    
    init() {}
    
    func lastMorningStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastMorningStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
