//
//  Watch.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/18/25.
//

import Foundation
import SwiftData

extension Watch {
    // Derived values
    nonisolated var isWatch: Bool { true }
    nonisolated var isConvective: Bool { true }
    nonisolated var isActive: Bool { true }
}

@Model
final class Watch {
    // 1/23/26 - updated the incomming value to be vtec.
    //           using the VTECDescriptor.eventKey allows
    //           us to get the event itself including updates
    //           and not just each message.
    // TODO: Need to rename this property some day
    @Attribute(.unique) var nwsId: String

    // properties.geocode
    var areaDesc: String        // human-readable region
    var ugcZones: [String]      // from geocode.UGC
    var sameCodes: [String]     // from geocode.SAME

    // properties
    var sent: Date
    var effective: Date
    var onset: Date
    var expires: Date
    var ends: Date
    var status: String          // "actual"
    var messageType: String     // "alert" | "update" | "cancel"
    var severity: String
    var certainty: String
    var urgency: String
    var event: String           // "Tornado Watch"
    var headline: String
    var watchDescription: String
    var sender: String?
    var instruction: String?
    var response: String?
    
//    var rawGeometry: Data?
      
    init(nwsId: String, areaDesc: String, ugcZones: [String], sameCodes: [String], sent: Date, effective: Date, onset: Date, expires: Date, ends: Date, status: String, messageType: String, severity: String, certainty: String, urgency: String, event: String, headline: String, watchDescription: String, sender: String, instruction: String, response: String, rawGeometry: Data? = nil) {
        self.nwsId = nwsId
        self.areaDesc = areaDesc
        self.ugcZones = ugcZones
        self.sameCodes = sameCodes
        self.sent = sent
        self.effective = effective
        self.onset = onset
        self.expires = expires
        self.ends = ends
        self.status = status
        self.messageType = messageType
        self.severity = severity
        self.certainty = certainty
        self.urgency = urgency
        self.event = event
        self.headline = headline
        self.watchDescription = watchDescription
        self.sender = sender
        self.instruction = instruction
        self.response = response
//        self.rawGeometry = rawGeometry
    }
}
