import Foundation

struct StormSetupPreferences: Sendable, Equatable {
    var stormSetupEnabled: Bool
    var detailedIngredientsEnabled: Bool

    init(stormSetupEnabled: Bool = false, detailedIngredientsEnabled: Bool = false) {
        self.stormSetupEnabled = stormSetupEnabled
        self.detailedIngredientsEnabled = detailedIngredientsEnabled
    }

    var effectiveDetailedIngredientsEnabled: Bool {
        stormSetupEnabled && detailedIngredientsEnabled
    }
}

struct StormSetupPolicyInput: Sendable, Equatable {
    let preferences: StormSetupPreferences
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let hasQualifyingConvectiveAlert: Bool
    let hasActiveMeso: Bool
    let assessmentOverall: StormSetupSignal?
    let payloadExpiresAt: Date?
    let now: Date
}

struct StormSetupFetchPolicy {
    static func shouldFetch(_ input: StormSetupPolicyInput) -> Bool {
        guard input.preferences.stormSetupEnabled else { return false }
        guard input.payloadExpiresAt.map({ $0 > input.now }) != true else { return false }

        return input.stormRisk.map { $0 >= .marginal } ?? false
            || input.severeRisk.map { $0 != .allClear } ?? false
            || input.hasQualifyingConvectiveAlert
            || input.hasActiveMeso
            || input.preferences.effectiveDetailedIngredientsEnabled
    }
}

struct StormSetupDisplayPolicy {
    static func shouldShow(_ input: StormSetupPolicyInput) -> Bool {
        guard input.preferences.stormSetupEnabled else { return false }
        guard input.payloadExpiresAt.map({ $0 > input.now }) == true else { return false }
        guard input.assessmentOverall != nil else { return false }

        return input.assessmentOverall == .supportive
            || input.assessmentOverall == .strong
            || input.hasQualifyingConvectiveAlert
            || input.hasActiveMeso
            || input.preferences.effectiveDetailedIngredientsEnabled
    }
}
