import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("Foreground Refresh Policies")
struct ForegroundRefreshPolicyTests {
    private let alertPolicy = AlertRefreshPolicy(minimumSyncInterval: 120)
    private let mapPolicy = MapProductRefreshPolicy(minimumSyncInterval: 600)

    @Test("alert policy syncs when there is no previous sync")
    func alertPolicy_syncsWithoutPreviousSync() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(alertPolicy.shouldSync(now: now, lastSync: nil, force: false))
    }

    @Test("alert policy skips before minimum interval")
    func alertPolicy_skipsBeforeMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-30)
        #expect(alertPolicy.shouldSync(now: now, lastSync: recent, force: false) == false)
    }

    @Test("map policy skips before minimum interval")
    func mapPolicy_skipsBeforeMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-300)
        #expect(mapPolicy.shouldSync(now: now, lastSync: recent, force: false) == false)
    }

    @Test("map policy force refresh bypasses interval guard")
    func mapPolicy_forceBypassesIntervalGuard() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recent = now.addingTimeInterval(-5)
        #expect(mapPolicy.shouldSync(now: now, lastSync: recent, force: true))
    }
}


