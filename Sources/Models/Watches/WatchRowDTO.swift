//
//  WatchRowDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/31/25.
//

import Foundation

extension WatchRowDTO: AlertItem {
    // Alert Item - Derived
    nonisolated var number: Int          {0}
    nonisolated var link: URL { URL(string:"https://api.weather.gov/alerts/\(self.messageId ?? "")")! } // link to full page
    nonisolated var validStart: Date     {self.issued}      // Valid start
    nonisolated var validEnd: Date       {self.ends}      // Valid end
    nonisolated var summary: String      {self.description}      // description / CDATA
    nonisolated var alertType: AlertType { AlertType.watch }      // Type of alert to conform to alert item
    nonisolated var severeRiskTags: String?       {self.SevereRiskTags}
    nonisolated var isUpdateMessage: Bool {
        messageType.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("update") == .orderedSame
    }
}

struct WatchRowDTO: Identifiable, Sendable, Hashable, Codable {
    // Identity
    let id: String              // nwsId
    let messageId: String?
    var currentRevisionSent: Date? = nil
    
    // Primary display
    let title: String           // "Tornado Watch"
    let headline: String        // Short descriptive text
    
    // Timing
    let issued: Date
    let expires: Date
    let ends: Date
    
    // Classification
    let messageType: String
    let sender: String?
    let severity: String
    let urgency: String
    let certainty: String

    // Data
    let description: String
    
    // Action
    let instruction: String?
    let response: String?
    
    // Geography (shortened / display-ready)
    let areaSummary: String     // e.g. "South Central Alabama"
    // Keep projection-cache persistence SwiftData-safe; use `geometry` at call sites.
    var geometryData: Data? = nil
    
    // CAP Params
    let tornadoDetection: String?
    let tornadoDamageThreat: String?
    let maxWindGust: String?
    let maxHailSize: String?
    let windThreat: String?
    let hailThreat: String?
    let thunderstormDamageThreat: String?
    let flashFloodDetection: String?
    let flashFloodDamageThreat: String?
    
    var SevereRiskTags: String? {
        // TODO: Package this logic to share between SkyAware and Arcus-Signal
        var tags: [String] = []
        switch title.lowercased() {
        case "severe thunderstorm warning":
            if normalizedCategory(tornadoDetection) == "possible" {
                tags.append("Tornado possible")
            }

            if let damageThreat = severeThunderstormDamageThreatTag(thunderstormDamageThreat) {
                tags.append(damageThreat)
            }

            if let windGust = windGustTag(maxWindGust) {
                tags.append(windGust)
            }

            if let hailSize = hailSizeTag(maxHailSize) {
                tags.append(hailSize)
            }

            if let hailThreat = hazardThreatTag(hailThreat, noun: "severe hail") {
                tags.append(hailThreat)
            }

            if let windThreat = hazardThreatTag(windThreat, noun: "severe winds") {
                tags.append(windThreat)
            }

        case "tornado warning":
            if let detection = tornadoDetectionTag(tornadoDetection) {
                tags.append(detection)
            }

            if let damageThreat = tornadoDamageThreatTag(tornadoDamageThreat) {
                tags.append(damageThreat)
            }

        case "flash flood warning":
            if let detection = floodDetectionTag(flashFloodDetection) {
                tags.append(detection)
            }

            if let damageThreat = flashFloodDamageThreatTag(flashFloodDamageThreat) {
                tags.append(damageThreat)
            }

        default:
            return nil
        }
        
        if tags.count > 0 {
            return tags.joined(separator: "\n")
        } else {
            return nil
        }
    }
}

extension WatchRowDTO {
    init(from watch: Watch) {
        self.id = watch.nwsId
        self.messageId = watch.messageId
        self.currentRevisionSent = watch.currentRevisionSent
        self.title = watch.event
        self.headline = watch.headline
        self.issued = watch.sent
        self.expires = watch.expires
        self.ends = watch.ends
        self.severity = watch.severity
        self.urgency = watch.urgency
        self.certainty = watch.certainty
        self.areaSummary = watch.areaDesc
        self.messageType = watch.messageType
        self.instruction = watch.instruction
        self.response = watch.response
        self.sender = watch.sender
        self.description = watch.watchDescription
        self.geometryData = watch.geometryData
        self.tornadoDetection = watch.tornadoDetection
        self.tornadoDamageThreat = watch.tornadoDamageThreat
        self.maxWindGust = watch.maxWindGust
        self.maxHailSize = watch.maxHailSize
        self.windThreat = watch.windThreat
        self.hailThreat = watch.hailThreat
        self.thunderstormDamageThreat = watch.thunderstormDamageThreat
        self.flashFloodDetection = watch.flashFloodDetection
        self.flashFloodDamageThreat = watch.flashFloodDamageThreat
    }
    
    var geometry: DeviceAlertGeometry? {
        get {
            DeviceAlertGeometry(encodedData: geometryData)
        }
        set {
            geometryData = newValue?.encodedData
        }
    }

    // MARK: CAP Severe Tag Parsing
    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }

    private func normalizedCategory(_ value: String?) -> String? {
        guard let trimmed = trimmedNonEmpty(value) else {
            return nil
        }

        let normalized = trimmed.normalizedLowercased
        guard normalized.isEmpty == false,
              normalized != "none",
              normalized != "unknown",
              normalized != "n/a" else {
            return nil
        }

        return normalized
    }

    private func severeThunderstormDamageThreatTag(_ value: String?) -> String? {
        switch normalizedCategory(value) {
        case "considerable":
            return "Considerable damage possible"
        case "destructive":
            return "Destructive winds possible"
        default:
            return nil
        }
    }

    private func tornadoDamageThreatTag(_ value: String?) -> String? {
        switch normalizedCategory(value) {
        case "considerable":
            return "Considerable tornado damage possible"
        case "catastrophic":
            return "Catastrophic tornado damage possible"
        default:
            return nil
        }
    }

    private func flashFloodDamageThreatTag(_ value: String?) -> String? {
        switch normalizedCategory(value) {
        case "considerable":
            return "Considerable flash flooding possible"
        case "catastrophic":
            return "Catastrophic flash flooding possible"
        default:
            return nil
        }
    }

    private func tornadoDetectionTag(_ value: String?) -> String? {
        switch normalizedCategory(value) {
        case "observed":
            return "Observed tornado"
        case "radar indicated":
            return "Radar indicated tornado"
        case "possible":
            return "Tornado possible"
        default:
            return nil
        }
    }

    private func floodDetectionTag(_ value: String?) -> String? {
        switch normalizedCategory(value) {
        case "observed":
            return "Observed flooding"
        case "radar indicated":
            return "Radar indicated flooding"
        default:
            return nil
        }
    }

    private func hazardThreatTag(_ value: String?, noun: String) -> String? {
        switch normalizedCategory(value) {
        case "observed":
            return "Observed \(noun)"
        case "radar indicated":
            return "Radar indicated \(noun)"
        default:
            return nil
        }
    }

    private func windGustTag(_ value: String?) -> String? {
        guard let trimmed = trimmedNonEmpty(value) else {
            return nil
        }

        let normalized = trimmed.normalizedLowercased
        if normalized.contains("mph") {
            return "Wind gusts up to \(trimmed)"
        }

        return "Wind gusts up to \(trimmed) mph"
    }

    private func hailSizeTag(_ value: String?) -> String? {
        guard let trimmed = trimmedNonEmpty(value) else {
            return nil
        }

        let normalized = trimmed.normalizedLowercased
        if normalized.contains("inch") || normalized.contains("in.") || normalized.contains("\"") {
            return "Hail up to \(trimmed)"
        }

        return "Hail up to \(trimmed) in"
    }

}
