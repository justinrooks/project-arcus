//
//  MesoComposer.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import OSLog

struct MesoComposer: NotificationComposer {
    private let logger = Logger.composer
    
    init() {}
    
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building meso notification")
        
        // MARK: Parse payload
        let mesoId = (event.payload["mesoId"] as? Int) ?? -1
        let threats = (event.payload["threats"] as? MDThreats) ?? nil
        let watchProbability = (event.payload["watchProbability"] as? String) ?? "Unknown"
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
        var threatString: String = "Threats: unknown"
        
        if let t = threats {
            threatString = "Threats: "
            if let w = t.peakWindMPH {
                threatString = "\nPeak Wind: \(w)"
            }
            
            if let h = t.hailRangeInches {
                threatString = "\nHail Range: \(h)"
            }
            
            if let ts = t.tornadoStrength, !ts.isEmpty {
                threatString = "\nTornado Strength: \(ts)"
            }
        }
        
        return threatString
    }
}
