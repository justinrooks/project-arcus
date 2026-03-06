//
//  MorningContext.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation

struct MorningContext: Sendable {
    let now: Date
    let lastConvectiveIssue: Date?
    let localTZ: TimeZone
    let quietHours: ClosedRange<Int>?
    let stormRisk: StormRiskLevel
    let severeRisk: SevereWeatherThreat
    let fireRisk: FireRiskLevel
    let placeMark: String
    
    init(
        now: Date,
        lastConvectiveIssue: Date?,
        localTZ: TimeZone,
        quietHours: ClosedRange<Int>?,
        stormRisk: StormRiskLevel,
        severeRisk: SevereWeatherThreat,
        fireRisk: FireRiskLevel,
        placeMark: String
    ) {
        self.now = now
        self.lastConvectiveIssue = lastConvectiveIssue
        self.localTZ = localTZ
        self.quietHours = quietHours
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.placeMark = placeMark
    }
}
