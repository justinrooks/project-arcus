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
    private let claims: NotificationClaimState
    
    init(store: NotificationStateStoring) {
        claims = NotificationClaimState(store: store, retention: .latest)
    }
    
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        logger.debug("Checking morning notification gate")
        guard let day = event.payload["localDay"] as? String else {
            logger.debug("Gate missing 'localDay' parameter")
            return false
        }
        
        guard await claims.claim(day) else {
            logger.debug("Already sent a notification for today")
            return false
        }

        logger.notice("Passed the gate")
        return true
    }

    func finish(_ event: NotificationEvent, didSchedule: Bool) async {
        guard let day = event.payload["localDay"] as? String else { return }
        await claims.finish(day, didSchedule: didSchedule)
    }
}

struct DefaultMorningStore: NotificationStateStoring {
    private let key = "skyaware.lastMorningNotifyLocalDay"
    
    func lastStamp() async -> String? { UserDefaults.standard.string(forKey: key) }
    func setLastStamp(_ stamp: String) async { UserDefaults.standard.set(stamp, forKey: key) }
}
