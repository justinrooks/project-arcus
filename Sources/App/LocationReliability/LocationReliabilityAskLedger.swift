import Foundation

struct LocationReliabilityAskLedgerSnapshot: Equatable {
    let askCount: Int
    let maxAsks: Int
    let lastCountedRailImpressionAt: Date?
    let lastCountedQualifyingDay: String?
    let lastSuppressedQualifyingDay: String?

    var hasExhaustedCap: Bool {
        askCount >= maxAsks
    }
}

struct LocationReliabilityAskLedger {
    static let defaultMaxAsks = 3

    private enum Keys {
        static let askCount = "fb016.locationReliability.askCount"
        static let lastCountedRailImpressionAt = "fb016.locationReliability.lastCountedRailImpressionAt"
        static let lastCountedQualifyingDay = "fb016.locationReliability.lastCountedQualifyingDay"
        static let lastSuppressedQualifyingDay = "fb016.locationReliability.lastSuppressedQualifyingDay"
    }

    private let userDefaults: UserDefaults
    private let maxAsks: Int

    init(userDefaults: UserDefaults = .standard, maxAsks: Int = defaultMaxAsks) {
        self.userDefaults = userDefaults
        self.maxAsks = maxAsks
    }

    @MainActor
    static func live(maxAsks: Int = defaultMaxAsks) -> LocationReliabilityAskLedger {
        LocationReliabilityAskLedger(userDefaults: UserDefaults.shared ?? .standard, maxAsks: maxAsks)
    }

    func snapshot() -> LocationReliabilityAskLedgerSnapshot {
        .init(
            askCount: max(0, userDefaults.integer(forKey: Keys.askCount)),
            maxAsks: maxAsks,
            lastCountedRailImpressionAt: userDefaults.object(forKey: Keys.lastCountedRailImpressionAt) as? Date,
            lastCountedQualifyingDay: userDefaults.string(forKey: Keys.lastCountedQualifyingDay),
            lastSuppressedQualifyingDay: userDefaults.string(forKey: Keys.lastSuppressedQualifyingDay)
        )
    }

    func recordCountedRailImpression(at date: Date, qualifyingDay: String) {
        let current = max(0, userDefaults.integer(forKey: Keys.askCount))
        if current < maxAsks {
            userDefaults.set(current + 1, forKey: Keys.askCount)
        }
        userDefaults.set(date, forKey: Keys.lastCountedRailImpressionAt)
        userDefaults.set(qualifyingDay, forKey: Keys.lastCountedQualifyingDay)
        userDefaults.set(qualifyingDay, forKey: Keys.lastSuppressedQualifyingDay)
    }

    func recordSameDaySuppression(qualifyingDay: String) {
        userDefaults.set(qualifyingDay, forKey: Keys.lastSuppressedQualifyingDay)
    }

    func resetForTesting() {
        userDefaults.removeObject(forKey: Keys.askCount)
        userDefaults.removeObject(forKey: Keys.lastCountedRailImpressionAt)
        userDefaults.removeObject(forKey: Keys.lastCountedQualifyingDay)
        userDefaults.removeObject(forKey: Keys.lastSuppressedQualifyingDay)
    }
}
