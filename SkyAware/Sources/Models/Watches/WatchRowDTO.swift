//
//  WatchRowDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/31/25.
//

import Foundation

extension WatchRowDTO {
    // Derived
    nonisolated var link: URL { URL(string:"https://api.weather.gov/alerts/\(self.id)")! } // link to full page
}

struct WatchRowDTO: Identifiable, Sendable {
    // Identity
    let id: String              // nwsId
    
    // Primary display
    let title: String           // "Tornado Watch"
    let headline: String        // Short descriptive text
    
    // Timing
    let issued: Date
    let expires: Date
    
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
}

extension WatchRowDTO {
    init(from watch: Watch) {
        self.id = watch.nwsId
        self.title = watch.event
        self.headline = watch.headline
        self.issued = watch.sent
        self.expires = watch.ends
        self.severity = watch.severity
        self.urgency = watch.urgency
        self.certainty = watch.certainty
        self.areaSummary = watch.areaDesc
        self.messageType = watch.messageType
        self.instruction = watch.instruction
        self.response = watch.response
        self.sender = watch.sender
        self.description = watch.watchDescription
    }
}
