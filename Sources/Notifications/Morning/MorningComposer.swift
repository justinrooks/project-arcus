//
//  MorningComposer.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct MorningComposer: NotificationComposing {
    private let logger = Logger.notificationsMorningComposer
    
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building morning summary notification")
        
        let winter = event.payload["winterImpact"] as? MorningContext.WinterImpact
        var outlookLines: [String] = [
            (event.payload["stormRisk"] as? StormRiskLevel).map { "Storm Activity: \($0.summary)" },
            (event.payload["severeRisk"] as? SevereWeatherThreat).map { "Severe Activity: \($0.summary)" },
            (event.payload["fireRisk"] as? FireRiskLevel).map { "Fire Risk: \($0.message)" }
        ].compactMap { $0 }
        let winterOnly = outlookLines.isEmpty && winter != nil
        if let winter {
            var style = Date.IntervalFormatStyle().month(.abbreviated).day().hour().minute()
            style.timeZone = winter.localTimeZone
            let period = (winter.sourceInterval.start..<winter.sourceInterval.end).formatted(style)
            outlookLines.append("\(winter.severity.rawValue) winter impacts are forecast for Day \(winter.day) (\(period)).")
        }

        let subtitle: String
        if winter != nil {
            subtitle = winterOnly ? "NOAA winter outlook" : ""
        } else {
            subtitle = (event.payload["issue"] as? Date)
                .map { "Issued: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Latest outlook loaded."
        }
        let placemark = (event.payload["placeMark"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let outlookTitle = winterOnly ? "Winter Impacts" : "Today's Outlook"
        let title: String
        if let placemark, placemark.isEmpty == false,
           ["unknown", "ready"].contains(placemark.lowercased()) == false {
            title = "\(outlookTitle) for \(placemark)"
        } else {
            title = outlookTitle
        }

        let outlook = outlookLines.joined(separator: "\n")
        var sections: [String] = []
        if let riskProfileChange = event.payload["riskProfileChange"] as? RiskProfileChange {
            let transitions = RiskProfileChangeFormatting.transitionLines(for: riskProfileChange)
            sections.append((["Risk Update"] + transitions).joined(separator: "\n"))
        }
        if !outlook.isEmpty { sections.append(outlook) }
        
        logger.debug("Summary notification generated")
        return (title, sections.joined(separator: "\n\n"), subtitle)
    }
}
