//
//  MesoComposer.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import OSLog

struct MesoComposer: NotificationComposing {
    private let logger = Logger.notificationsMesoComposer
    
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building meso notification")
        
        // MARK: Parse payload
        let mesoId = (event.payload["mesoId"] as? Int) ?? -1
        let threats = (event.payload["threats"] as? MDThreats) ?? nil
        let watchProbability = formatWatchProbability(
            value: event.payload["watchProbability"] as? Double,
            text: event.payload["watchProbabilityText"] as? String
        )
        let placemark = (event.payload["placeMark"] as? String) ?? "Unknown"
        
        let threatString = buildThreatString(from: threats)
        
        logger.debug("Summary notification generated")
        return (
            "MD\(mesoId) Active mesoscale discussion for \(placemark)",
            "\(threatString)",
            "Watch Probability: \(watchProbability)"
        )
    }
    
    // MARK: Build Strings
    private func buildThreatString(from threats: MDThreats?) -> String {
        guard let t = threats else { return "Threats: unknown" }
        
        var lines: [String] = ["Threats:"]
        if let w = t.peakWindMPH {
            lines.append("Peak Wind: \(w)")
        }
        if let h = t.hailRangeInches {
            lines.append("Hail Range: \(h)")
        }
        if let ts = t.tornadoStrength, !ts.isEmpty {
            lines.append("Tornado Strength: \(ts)")
        }
        
        return lines.count == 1 ? "Threats: unknown" : lines.joined(separator: "\n")
    }

    private func formatWatchProbability(value: Double?, text: String?) -> String {
        if let value {
            return "\(Int(value.rounded()))%"
        }

        guard let rawText = text?.trimmingCharacters(in: .whitespacesAndNewlines), rawText.isEmpty == false else {
            return "Unknown"
        }

        if let numericValue = Double(rawText) {
            return "\(Int(numericValue.rounded()))%"
        }

        return rawText.localizedCaseInsensitiveCompare("unknown") == .orderedSame ? "Unknown" : rawText
    }
}
