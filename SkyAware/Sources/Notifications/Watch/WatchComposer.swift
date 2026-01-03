//
//  WatchComposer.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/2/26.
//

import Foundation
import OSLog

struct WatchComposer: NotificationComposing {
    private let logger = Logger.watchComposer
    
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        logger.debug("Building watch notification")
        
        // MARK: Parse payload
        let title = (event.payload["title"] as? String) ?? "Unknown"
        let sender = (event.payload["sender"] as? String) ?? "Unknown"
        let placemark = (event.payload["placeMark"] as? String) ?? "Unknown"
        
        let threatString = buildAlertDetailString(from: event.payload)
        
        logger.debug("Summary notification generated")
        return (
            "\(title) for \(placemark)",
            "\(threatString)",
            "Issued by: \(sender)"
        )
    }
    
    // MARK: Build Strings
    private func buildAlertDetailString(from payload: [String: any Sendable]) -> String {
        var lines: [String] = ["Alert Details"]
        if let c = payload["certainty"] as? String {
            lines.append("Certainty: \(c)")
        }
        
        if let s = payload["severity"] as? String {
            lines.append("Severity: \(s)")
        }
        
        if let u = payload["urgency"] as? String {
            lines.append("Urgency: \(u)")
        }
        
        return lines.count == 1 ? "Alert Details: unknown" : lines.joined(separator: "\n")
    }
}
