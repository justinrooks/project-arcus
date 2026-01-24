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
}

struct WatchRowDTO: Identifiable, Sendable, Hashable {
    // Identity
    let id: String              // nwsId
    let messageId: String?
    
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
}

extension WatchRowDTO {
    init(from watch: Watch) {
        self.id = watch.nwsId
        self.messageId = watch.messageId
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
    }
}
