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
        let threats = (event.payload["threats"] as? MDThreats) ?? nil
        let watchProbabilitySubtitle = formatWatchProbabilitySubtitle(
            value: event.payload["watchProbability"] as? Double,
            text: event.payload["watchProbabilityText"] as? String
        )
        let placemark = sanitizedPlacemark(event.payload["placeMark"] as? String)
        
        let threatString = buildThreatSummary(from: threats)
        
        logger.debug("Summary notification generated")
        return (
            "Mesoscale Discussion for \(placemark)",
            "\(threatString)",
            "\(watchProbabilitySubtitle)"
        )
    }
    
    // MARK: Build Strings
    private func buildThreatSummary(from threats: MDThreats?) -> String {
        guard let threats else {
            return "SPC is monitoring storms near your area. Open SkyAware for the full discussion."
        }

        let hasWind = threats.peakWindMPH != nil
        let hasHail = threats.hailRangeInches != nil
        let hasTornado = isMeaningfulThreatText(threats.tornadoStrength)

        var concerns: [String] = []
        if hasWind { concerns.append("damaging wind") }
        if hasHail { concerns.append("large hail") }
        if hasTornado { concerns.append("isolated tornadoes") }

        guard concerns.isEmpty == false else {
            return "SPC is monitoring storms near your area. Open SkyAware for the full discussion."
        }

        let lead = concerns.count == 1
            ? "Main concern: \(concerns[0])."
            : "Main concerns: \(naturalLanguageList(concerns))."

        var detailParts: [String] = []
        if let wind = threats.peakWindMPH {
            detailParts.append("Gusts near \(wind) mph")
        }
        if let hail = threats.hailRangeInches {
            detailParts.append("hail up to \(formatHailInches(hail))")
        }

        if detailParts.isEmpty {
            return lead
        }

        return "\(lead) \(detailParts.joined(separator: "; "))."
    }

    private func formatWatchProbabilitySubtitle(value: Double?, text: String?) -> String {
        if let value {
            return "Watch issuance chance: \(Int(value.rounded()))%"
        }

        guard let rawText = text?.trimmingCharacters(in: .whitespacesAndNewlines), rawText.isEmpty == false else {
            return "Watch potential not specified"
        }

        if let numericValue = Double(rawText) {
            return "Watch possible: \(Int(numericValue.rounded()))%"
        }

        return rawText.localizedCaseInsensitiveCompare("unknown") == .orderedSame
            ? "Watch potential not specified"
            : "Watch possible: \(rawText)"
    }

    private func sanitizedPlacemark(_ placemark: String?) -> String {
        let trimmed = placemark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed.localizedCaseInsensitiveCompare("unknown") == .orderedSame {
            return "your area"
        }
        return trimmed
    }

    private func isMeaningfulThreatText(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else {
            return false
        }
        return text.localizedCaseInsensitiveCompare("unknown") != .orderedSame
    }

    private func naturalLanguageList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last ?? "")"
        }
    }

    private func formatHailInches(_ inches: Double) -> String {
        let value: String
        if inches.truncatingRemainder(dividingBy: 1) == 0 {
            value = String(Int(inches))
        } else {
            value = String(format: "%.1f", inches)
        }
        return "\(value)\""
    }
}
