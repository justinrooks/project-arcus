//
//  MesoRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import OSLog
import MapKit

struct MesoRule: MesoNotificationRuleEvaluating {
    private let logger = Logger.notificationsMesoRule
    
    func evaluate(_ ctx: MesoContext) -> NotificationEvent? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ctx.localTZ
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: ctx.now)
        
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil}
        
        // MARK: Rule
        let activeMesos = ctx.mesos.filter { $0.validEnd >= ctx.now }
        if activeMesos.isEmpty {
            logger.debug("No active mesos for current time and location")
            return nil
        }
        if activeMesos.count > 1 { logger.warning("Multiple mesos found, only using most recent") }
        
        let meso: MdDTO? = activeMesos.max(by: { $0.issued < $1.issued }) // Get the most recently issued meso
        
        guard let meso else { return nil }
        
        // MARK: Stamp
        let stamp = String(format: "%04d-%02d-%02d", y, m, d) // day stamp
        let id = "meso:\(stamp)-\(meso.number)"
        logger.trace("Stamp generated: \(id)")
        
        return NotificationEvent(
            kind: .mesoNotification,
            key: id,
            payload: [
                "localDay": stamp,
                "mesoId": meso.number,
                "threats": meso.threats,
                "issue": meso.issued,
                "validStart": meso.validStart,
                "validEnd": meso.validEnd,
                "watchProbability": meso.watchProbability,
                "placeMark": ctx.placeMark
            ]
        )
    }
}
