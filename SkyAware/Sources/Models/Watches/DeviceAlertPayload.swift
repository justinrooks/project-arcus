//
//  DeviceAlertPayload.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

public enum DeviceAlertPayloadError: Error, Sendable {
    case missingRequired(field: String)
    case invalidGeometryJSON
}

public struct DeviceAlertPayload: Sendable, Codable {
    // MARK: Identity
    let id: UUID // Series Id
    let event: String // event property in the message Tornado Watch
    let currentRevisionUrn: String
    let currentRevisionSent: Date?
    let messageType: String

    // MARK: Lifecycle
    let state: String // Active|Expired|Cancelled
    let created: Date
    let updated: Date
    let lastSeenActive: Date
    
    // MARK: Timing
    let sent: Date? // time of the origination of message itself
    let effective: Date? // goes into effect
    let onset: Date? // beginning of the event in message
    let expires: Date? // alert message expiration
    let ends: Date?
    
    // MARK: Severity inputs (normalized)
    let severity: String
    let urgency: String
    let certainty: String
    
    // MARK: Human-facing metadata
    let areaDesc: String?
    let senderName: String?
    let headline: String?
    let description: String?
    let instructions: String?
    let response: String?
    
    // Arcus can return cell-only matches without UGC metadata.
    let ugc: [String]?
    var h3Cells: [Int64]?
}
