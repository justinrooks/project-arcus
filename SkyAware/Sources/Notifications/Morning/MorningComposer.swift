//
//  MorningComposer.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct MorningComposer: NotificationComposing {
    private let logger = Logger.composer
    
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building morning summary notification")
        
//        let day = (event.payload["localDay"] as? String) ?? ""
        let issue = (event.payload["issue"] as? Date).map { "Issued: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Latest outlook loaded."
        let stormRisk = (event.payload["stormRisk"] as? StormRiskLevel) ?? .allClear
        let severeRisk = (event.payload["severeRisk"] as? SevereWeatherThreat) ?? .allClear
        let placemark = (event.payload["placeMark"] as? String) ?? "Unknown"
        
        logger.debug("Summary notification generated")
        return ("Today's Outlook for \(placemark)", "Storm Activity: \(stormRisk.summary)\nSevere Activity: \(severeRisk.summary)", "\(issue)")
    }
}
