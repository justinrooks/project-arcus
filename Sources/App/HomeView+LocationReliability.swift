import ArcusCore
import Foundation

extension HomeView {
    struct LocationReliabilityRailState: Equatable {
        let shouldShowRail: Bool
        let qualifyingDay: String?
        let shouldRecordImpression: Bool
    }

    static func locationReliabilityRailState(
        reliability: LocationReliabilityState,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        ledger: LocationReliabilityAskLedgerSnapshot,
        now: Date,
        timeZone: TimeZone,
        currentlyShownQualifyingDay: String?
    ) -> LocationReliabilityRailState {
        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            ledger: ledger,
            now: now,
            timeZone: timeZone
        )

        guard decision.isEligible else {
            return .init(shouldShowRail: false, qualifyingDay: nil, shouldRecordImpression: false)
        }

        let qualifyingDay = LocationReliabilitySummaryRailEligibility.localDayString(for: now, timeZone: timeZone)
        let shouldRecordImpression = currentlyShownQualifyingDay != qualifyingDay
        return .init(
            shouldShowRail: true,
            qualifyingDay: qualifyingDay,
            shouldRecordImpression: shouldRecordImpression
        )
    }
}
