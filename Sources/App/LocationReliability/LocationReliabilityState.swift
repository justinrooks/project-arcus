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

enum LocationReliabilitySettingsAction: Equatable {
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

    var settingsAuthorizationText: String {
        switch authorization {
        case .always:
            return "Always"
        case .whileUsing:
            return "While Using"
        case .denied:
            return "Off"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Set"
        }
    }

    var settingsAccuracyText: String {
        switch accuracy {
        case .precise:
            return "Precise"
        case .reduced:
            return "Reduced"
        case .unknown:
            return "Unknown"
        }
    }

    var settingsReliabilityCopy: String {
        switch authorization {
        case .always:
            switch accuracy {
            case .precise:
                return "Background alerts are set up for the best reliability."
            case .reduced:
                return "Background alerts are enabled. Precise Location can make alerts more accurate for your area."
            case .unknown:
                return "Background alerts are enabled. Check your location settings to improve reliability."
            }
        case .whileUsing:
            switch accuracy {
            case .precise:
                return "SkyAware can alert while you are using the app. Enable Always for more reliable background alerts."
            case .reduced:
                return "SkyAware can alert while you are using the app. Enable Always and Precise Location for more reliable alerts."
            case .unknown:
                return "SkyAware can alert while you are using the app. Enable Always for more reliable alerts."
            }
        case .denied, .restricted:
            return "Location is off for SkyAware. Enable location to receive alerts for your area."
        case .notDetermined:
            return "Choose how SkyAware can use location to send alerts for your area."
        }
    }

    var settingsAction: LocationReliabilitySettingsAction {
        switch nextAction {
        case .requestWhenInUse:
            return .requestWhenInUse
        case .requestAlwaysUpgrade:
            return .openSettings
        case .openSettings:
            return .openSettings
        case .none:
            return .none
        }
    }

    var settingsActionTitle: String? {
        switch nextAction {
        case .requestWhenInUse:
            return "Enable Location"
        case .requestAlwaysUpgrade:
            return "Enable Always"
        case .openSettings:
            return "Open Settings"
        case .none:
            return nil
        }
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

extension LocationReliabilityAuthorization {
    var logName: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .whileUsing:
            return "whileUsing"
        case .always:
            return "always"
        }
    }
}

extension LocationReliabilityAccuracy {
    var logName: String {
        switch self {
        case .precise:
            return "precise"
        case .reduced:
            return "reduced"
        case .unknown:
            return "unknown"
        }
    }
}

extension LocationReliabilityNextAction {
    var logName: String {
        switch self {
        case .none:
            return "none"
        case .requestWhenInUse:
            return "requestWhenInUse"
        case .requestAlwaysUpgrade:
            return "requestAlwaysUpgrade"
        case .openSettings:
            return "openSettings"
        }
    }
}

extension LocationReliabilitySettingsAction {
    var logName: String {
        switch self {
        case .none:
            return "none"
        case .requestWhenInUse:
            return "requestWhenInUse"
        case .requestAlwaysUpgrade:
            return "requestAlwaysUpgrade"
        case .openSettings:
            return "openSettings"
        }
    }
}

extension LocationReliabilitySummaryRailEligibilityReason {
    var logName: String {
        switch self {
        case .eligible:
            return "eligible"
        case .authorizationNotWhileUsing:
            return "authorizationNotWhileUsing"
        case .notElevatedRisk:
            return "notElevatedRisk"
        case .askCapExhausted:
            return "askCapExhausted"
        case .sameDaySuppressed:
            return "sameDaySuppressed"
        case .waitingForNextQualifyingDay:
            return "waitingForNextQualifyingDay"
        case .waitingForMinimumInterval:
            return "waitingForMinimumInterval"
        }
    }
}
