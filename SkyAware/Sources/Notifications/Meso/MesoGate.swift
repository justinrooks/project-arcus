//
//  MesoGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import OSLog

struct MesoGate: NotificationGate {
    private let logger = Logger.mesoGate
    private let store: NotificationStateStore
    
    init(store: NotificationStateStore) {
        self.store = store
    }
    
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking meso notification gate")
//        guard let day = event.payload["localDay"] as? String else {
//            logger.debug("Gate missing 'localDay' parameter")
//            return false
//        }
        
        guard let mesoId = event.payload["mesoId"] as? String else {
            logger.debug("Gate missing 'mesoId' parameter")
            return false
        }
  
        let last = await store.lastStamp()
        guard last != event.key else {
            logger.debug("Already sent a notification for meso \(mesoId) today")
            return false
        }
        
        logger.debug("Updating the store stamp")
        await store.setLastStamp(event.key)
        
        logger.info("Passed the gate")
        return true
    }
}

struct DefaultMesoStore: NotificationStateStore {
    private let key = "skyaware.lastMesoNotifyLocalDay"
    
    init() {}
    
    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
