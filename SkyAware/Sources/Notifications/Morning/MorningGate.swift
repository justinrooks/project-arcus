//
//  MorningGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct MorningGate: NotificationGating {
    private let logger = Logger.notificationsMorningGate
    private let store: NotificationStateStoring
    
    init(store: NotificationStateStoring) {
        self.store = store
    }
    
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking morning notification gate")
        guard let day = event.payload["localDay"] as? String else {
            logger.debug("Gate missing 'localDay' parameter")
            return false
        }
        
        let last = await store.lastStamp()
        guard last != day else {
            logger.debug("Already sent a notification for today")
            return false
        }
        
        logger.debug("Updating the morning store stamp")
        await store.setLastStamp(day)
        
        logger.notice("Passed the gate")
        return true
    }
}

struct DefaultMorningStore: NotificationStateStoring {
    private let key = "skyaware.lastMorningNotifyLocalDay"
    
    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
