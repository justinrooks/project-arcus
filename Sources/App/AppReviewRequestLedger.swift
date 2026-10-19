import Foundation

@MainActor
struct AppReviewRequestLedger {
    static let successfulRefreshThreshold = 4

    private enum Keys {
        static let successfulManualRefreshCount = "appReview.successfulManualRefreshCount"
        static let lastAttemptedAppVersion = "appReview.lastAttemptedAppVersion"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    static func live() -> AppReviewRequestLedger {
        AppReviewRequestLedger(userDefaults: UserDefaults.shared ?? .standard)
    }

    var successfulManualRefreshCount: Int {
        max(0, userDefaults.integer(forKey: Keys.successfulManualRefreshCount))
    }

    func recordSuccessfulManualRefresh() {
        userDefaults.set(successfulManualRefreshCount + 1, forKey: Keys.successfulManualRefreshCount)
    }

    func isEligible(
        appVersion: String,
        onboardingComplete: Bool,
        hasActiveAlerts: Bool
    ) -> Bool {
        onboardingComplete &&
            !hasActiveAlerts &&
            successfulManualRefreshCount >= Self.successfulRefreshThreshold &&
            userDefaults.string(forKey: Keys.lastAttemptedAppVersion) != appVersion
    }

    func recordAttempted(appVersion: String) {
        userDefaults.set(appVersion, forKey: Keys.lastAttemptedAppVersion)
    }
}
