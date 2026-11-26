//
//  MorningContext.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation

struct MorningContext: Sendable {
    struct WinterImpact: Sendable {
        let day: Int
        let severity: WSSISeverity
        let sourceInterval: DateInterval
        let localTimeZone: TimeZone
    }

    private(set) var now: Date
    let lastConvectiveIssue: Date?
    let localTZ: TimeZone
    let quietHours: ClosedRange<Int>?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    private(set) var winterImpact: WinterImpact?
    let placeMark: String?
    let riskProfileChange: RiskProfileChange?
    
    init(
        now: Date,
        lastConvectiveIssue: Date?,
        localTZ: TimeZone,
        quietHours: ClosedRange<Int>?,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?,
        placeMark: String?,
        riskProfileChange: RiskProfileChange? = nil,
        acceptedWinterAssessment: WSSIAcceptedAssessment? = nil,
        currentWinterLocation: WSSIAcceptedAssessment.Location? = nil,
        winterImpactsEnabled: Bool = false
    ) {
        self.now = now
        self.lastConvectiveIssue = lastConvectiveIssue
        self.localTZ = localTZ
        self.quietHours = quietHours
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.placeMark = placeMark
        self.riskProfileChange = riskProfileChange

        if winterImpactsEnabled, let acceptedWinterAssessment,
           let day = WinterImpactsPresentation(
               accepted: acceptedWinterAssessment, currentLocation: currentWinterLocation, enabled: true, at: now
           ).morningDay,
           let severity = day.overall.severity, let sourceInterval = day.overall.sourceInterval {
            winterImpact = .init(day: day.number, severity: severity, sourceInterval: sourceInterval, localTimeZone: localTZ)
        } else {
            winterImpact = nil
        }
    }

    func atDeliveryTime(_ time: Date, includeWinter: Bool) -> Self {
        var context = self
        context.now = time
        if let winterImpact, !includeWinter || time >= winterImpact.sourceInterval.end {
            context.winterImpact = nil
        }
        return context
    }
}
