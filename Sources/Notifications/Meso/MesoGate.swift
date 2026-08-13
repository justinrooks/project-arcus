//
//  MesoGate.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import OSLog

struct MesoGate: NotificationGating {
    private let logger = Logger.notificationsMesoGate
    private let claims: NotificationClaimState
    
    init(store: NotificationStateStoring) {
        claims = NotificationClaimState(store: store, retention: .latest)
    }
    
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking meso notification gate")
//        guard let day = event.payload["localDay"] as? String else {
//            logger.debug("Gate missing 'localDay' parameter")
//            return false
//        }
        
        guard let mesoId = event.payload["mesoId"] as? Int else {
            logger.debug("Gate missing 'mesoId' parameter")
            return false
        }
  
        guard await claims.claim(event.key) else {
            logger.debug("Already sent a notification for meso \(mesoId, privacy: .public) today")
            return false
        }

        logger.notice("Passed the gate")
        return true
    }

    func finish(_ event: NotificationEvent, didSchedule: Bool) async {
        guard event.payload["mesoId"] is Int else { return }
        await claims.finish(event.key, didSchedule: didSchedule)
    }
}

struct DefaultMesoStore: NotificationStateStoring {
    private let key = "skyaware.lastMesoNotifyLocalDay"
    
    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
