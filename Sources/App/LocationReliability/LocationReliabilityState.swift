import CoreLocation
import Foundation

enum LocationReliabilityAuthorization: Equatable {
    case notDetermined
    case denied
    case restricted
    case whileUsing
    case always
}

enum LocationReliabilityAccuracy: Equatable {
    case precise
    case reduced
    case unknown
}

enum LocationReliabilityNextAction: Equatable {
    case none
    case requestWhenInUse
    case requestAlwaysUpgrade
    case openSettings
}

struct LocationReliabilityState: Equatable {
    static let recommendedAuthorization: LocationReliabilityAuthorization = .always
    static let recommendedAccuracy: LocationReliabilityAccuracy = .precise

    let authorization: LocationReliabilityAuthorization
    let accuracy: LocationReliabilityAccuracy
    let recommendedAuthorization: LocationReliabilityAuthorization
    let recommendedAccuracy: LocationReliabilityAccuracy
    let upgradeAvailable: Bool
    let nextAction: LocationReliabilityNextAction

    var isRecommended: Bool {
        authorization == recommendedAuthorization && accuracy == recommendedAccuracy
    }

    init(
        authorization: LocationReliabilityAuthorization,
        accuracy: LocationReliabilityAccuracy,
        recommendedAuthorization: LocationReliabilityAuthorization = Self.recommendedAuthorization,
        recommendedAccuracy: LocationReliabilityAccuracy = Self.recommendedAccuracy,
        nextAction: LocationReliabilityNextAction? = nil
    ) {
        self.authorization = authorization
        self.accuracy = accuracy
        self.recommendedAuthorization = recommendedAuthorization
        self.recommendedAccuracy = recommendedAccuracy

        let resolvedAction = nextAction ?? Self.defaultNextAction(
            authorization: authorization,
            accuracy: accuracy,
            recommendedAuthorization: recommendedAuthorization,
            recommendedAccuracy: recommendedAccuracy
        )
        self.nextAction = resolvedAction
        self.upgradeAvailable = resolvedAction != .none
    }

    init(
        authorizationStatus: CLAuthorizationStatus,
        accuracyAuthorization: CLAccuracyAuthorization?
    ) {
        let authorization = Self.mapAuthorization(authorizationStatus)
        let accuracy = Self.mapAccuracy(accuracyAuthorization)
        self.init(authorization: authorization, accuracy: accuracy)
    }

    private static func defaultNextAction(
        authorization: LocationReliabilityAuthorization,
        accuracy: LocationReliabilityAccuracy,
        recommendedAuthorization: LocationReliabilityAuthorization,
        recommendedAccuracy: LocationReliabilityAccuracy
    ) -> LocationReliabilityNextAction {
        if authorization == recommendedAuthorization && accuracy == recommendedAccuracy {
            return .none
        }

        switch authorization {
        case .notDetermined:
            return .requestWhenInUse
        case .whileUsing:
            return .requestAlwaysUpgrade
        case .denied, .restricted:
            return .openSettings
        case .always:
            return accuracy == .reduced ? .openSettings : .none
        }
    }

    private static func mapAuthorization(_ value: CLAuthorizationStatus) -> LocationReliabilityAuthorization {
        switch value {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorizedWhenInUse:
            return .whileUsing
        case .authorizedAlways:
            return .always
        @unknown default:
            return .notDetermined
        }
    }

    private static func mapAccuracy(_ value: CLAccuracyAuthorization?) -> LocationReliabilityAccuracy {
        guard let value else { return .unknown }
        switch value {
        case .fullAccuracy:
            return .precise
        case .reducedAccuracy:
            return .reduced
        @unknown default:
            return .unknown
        }
    }
}

enum LocationReliabilitySummaryRailEligibilityReason: Equatable {
    case eligible
    case authorizationNotWhileUsing
    case notElevatedRisk
    case askCapExhausted
    case sameDaySuppressed
    case waitingForNextQualifyingDay
    case waitingForMinimumInterval
}

struct LocationReliabilitySummaryRailDecision: Equatable {
    let isEligible: Bool
    let reason: LocationReliabilitySummaryRailEligibilityReason
}

struct LocationReliabilitySummaryRailEligibility {
    static let minimumAskInterval: TimeInterval = 24 * 60 * 60

    static func decision(
        reliability: LocationReliabilityState,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        ledger: LocationReliabilityAskLedgerSnapshot,
        now: Date,
        timeZone: TimeZone
    ) -> LocationReliabilitySummaryRailDecision {
        guard reliability.authorization == .whileUsing else {
            return .init(isEligible: false, reason: .authorizationNotWhileUsing)
        }

        guard isElevatedRisk(stormRisk: stormRisk, severeRisk: severeRisk) else {
            return .init(isEligible: false, reason: .notElevatedRisk)
        }

        guard ledger.askCount < ledger.maxAsks else {
            return .init(isEligible: false, reason: .askCapExhausted)
        }

        let qualifyingDay = localDayString(for: now, timeZone: timeZone)

        if let suppressedDay = ledger.lastSuppressedQualifyingDay, suppressedDay == qualifyingDay {
            return .init(isEligible: false, reason: .sameDaySuppressed)
        }

        if let lastDay = ledger.lastCountedQualifyingDay, lastDay >= qualifyingDay {
            return .init(isEligible: false, reason: .waitingForNextQualifyingDay)
        }

        if let lastImpressionAt = ledger.lastCountedRailImpressionAt,
           now.timeIntervalSince(lastImpressionAt) < minimumAskInterval {
            return .init(isEligible: false, reason: .waitingForMinimumInterval)
        }

        return .init(isEligible: true, reason: .eligible)
    }

    static func isElevatedRisk(stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?) -> Bool {
        if let stormRisk, stormRisk >= .marginal {
            return true
        }

        guard let severeRisk else { return false }
        switch severeRisk {
        case .hail, .tornado:
            return true
        case .allClear, .wind:
            return false
        }
    }

    static func localDayString(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
