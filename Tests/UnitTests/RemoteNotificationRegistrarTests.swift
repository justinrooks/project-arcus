import Foundation
import Testing
import UserNotifications
@testable import SkyAware

@Suite("RemoteNotificationRegistrar")
struct RemoteNotificationRegistrarTests {
    private actor DrainCounter {
        private var count = 0

        func increment() {
            count += 1
        }

        func value() -> Int {
            count
        }
    }

    private final class MockInstallationStorage: @unchecked Sendable {
        private let lock = NSLock()
        private var storedValue: String?
        private var readCount = 0
        private var writes: [String] = []
        private let shouldWriteSucceed: Bool

        init(storedValue: String? = nil, shouldWriteSucceed: Bool = true) {
            self.storedValue = storedValue
            self.shouldWriteSucceed = shouldWriteSucceed
        }

        func read() -> String? {
            lock.lock()
            defer { lock.unlock() }
            readCount += 1
            return storedValue
        }

        func write(_ value: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            writes.append(value)
            if shouldWriteSucceed {
                storedValue = value
            }
            return shouldWriteSucceed
        }

        func snapshot() -> (storedValue: String?, readCount: Int, writes: [String]) {
            lock.lock()
            defer { lock.unlock() }
            return (storedValue, readCount, writes)
        }
    }

    @Test("Formats APNs token as lowercase hex")
    func formatsTokenAsLowercaseHex() {
        let tokenData = Data([0x00, 0x01, 0x0A, 0xAF, 0xFF, 0x10])
        let value = RemoteNotificationRegistrar.deviceTokenString(from: tokenData)
        #expect(value == "00010aafff10")
    }

    @Test("Handles empty APNs token data")
    func handlesEmptyToken() {
        let value = RemoteNotificationRegistrar.deviceTokenString(from: Data())
        #expect(value.isEmpty)
    }

    @MainActor
    @Test("waitForDeviceToken returns stored token immediately")
    func waitForDeviceToken_returnsStoredValue() async {
        let suiteName = "RemoteNotificationRegistrarTests.waitForDeviceToken_returnsStoredValue"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        defaults?.set("existing-token", forKey: RemoteNotificationRegistrar.apnsDeviceTokenKey)

        let sut = RemoteNotificationRegistrar(
            center: .current(),
            userDefaults: defaults,
            registerRemoteNotifications: {}
        )

        let token = await sut.waitForDeviceToken(timeout: .seconds(1))
        #expect(token == "existing-token")
    }

    @MainActor
    @Test("waitForDeviceToken resumes when token is stored later")
    func waitForDeviceToken_resumesAfterStore() async throws {
        let suiteName = "RemoteNotificationRegistrarTests.waitForDeviceToken_resumesAfterStore"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)

        let sut = RemoteNotificationRegistrar(
            center: .current(),
            userDefaults: defaults,
            registerRemoteNotifications: {}
        )

        let tokenTask = Task { @MainActor in
            await sut.waitForDeviceToken(timeout: .seconds(1))
        }

        try await Task.sleep(for: .milliseconds(50))
        sut.storeDeviceToken(Data([0x00, 0xAB, 0x10]))

        let token = await tokenTask.value
        #expect(token == "00ab10")
    }

    @MainActor
    @Test("storeDeviceToken notifies token observer once per store event")
    func storeDeviceToken_notifiesObserverOncePerStoreEvent() async {
        let suiteName = "RemoteNotificationRegistrarTests.storeDeviceToken_notifiesObserverOncePerStoreEvent"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        let counter = DrainCounter()

        let sut = RemoteNotificationRegistrar(
            center: .current(),
            userDefaults: defaults,
            registerRemoteNotifications: {}
        )
        let observerCompletion = AsyncStream<Void> { continuation in
            sut.setTokenStoredObserver { _ in
                await counter.increment()
                continuation.yield(())
                continuation.finish()
            }
        }

        var observerEvents = observerCompletion.makeAsyncIterator()
        sut.storeDeviceToken(Data([0x01, 0x02, 0x03]))

        let observedEvent = await observerEvents.next()
        #expect(observedEvent != nil)
        #expect(await counter.value() == 1)
    }

    @Test("InstallationIdentityStore returns existing ID without writing")
    func installationIdentity_returnsExistingId() async {
        let storage = MockInstallationStorage(storedValue: "existing-install-id")
        let sut = InstallationIdentityStore(
            readInstallationId: { storage.read() },
            writeInstallationId: { storage.write($0) }
        )

        let value = await sut.installationId()
        let snapshot = storage.snapshot()

        #expect(value == "existing-install-id")
        #expect(snapshot.readCount == 1)
        #expect(snapshot.writes.isEmpty)
    }

    @Test("InstallationIdentityStore generates once and caches value")
    func installationIdentity_generatesOnceAndCaches() async {
        let storage = MockInstallationStorage(storedValue: nil)
        let sut = InstallationIdentityStore(
            readInstallationId: { storage.read() },
            writeInstallationId: { storage.write($0) }
        )

        let first = await sut.installationId()
        let second = await sut.installationId()
        let snapshot = storage.snapshot()

        #expect(!first.isEmpty)
        #expect(first == second)
        #expect(snapshot.writes.count == 1)
        #expect(snapshot.storedValue == first)
    }
}

@Suite("Notification preference state")
struct NotificationPreferenceStateTests {
    @Test("denied keeps stored preferences and exposes an Open Settings recovery action")
    func denied_keepsStoredPreferencesAndRecoveryAction() {
        let state = NotificationPreferenceState(
            authorizationStatus: .denied,
            morningSummariesEnabled: true,
            mesoNotificationsEnabled: true,
            serverNotificationsEnabled: true
        )

        #expect(state.authorizationStatusTitle == "Off")
        #expect(state.allowsNotificationDelivery == false)
        #expect(state.effectiveMorningSummariesEnabled == false)
        #expect(state.effectiveMesoNotificationsEnabled == false)
        #expect(state.effectiveServerNotificationsEnabled == false)
        #expect(state.recoveryActionTitle == "Open Settings")
        #expect(state.systemAvailabilityCopy.contains("preserved"))
    }

    @Test("provisional notifications remain effectively available without a recovery action")
    func provisional_remainsAvailable() {
        let state = NotificationPreferenceState(
            authorizationStatus: .provisional,
            morningSummariesEnabled: true,
            mesoNotificationsEnabled: false,
            serverNotificationsEnabled: true
        )

        #expect(state.authorizationStatusTitle == "Quiet")
        #expect(state.allowsNotificationDelivery == true)
        #expect(state.effectiveMorningSummariesEnabled == true)
        #expect(state.effectiveMesoNotificationsEnabled == false)
        #expect(state.effectiveServerNotificationsEnabled == true)
        #expect(state.recoveryActionTitle == nil)
        #expect(state.systemAvailabilityCopy.contains("quietly"))
    }

    @Test("ephemeral notifications remain effectively available without a recovery action")
    func ephemeral_remainsAvailable() {
        let state = NotificationPreferenceState(
            authorizationStatus: .ephemeral,
            morningSummariesEnabled: false,
            mesoNotificationsEnabled: true,
            serverNotificationsEnabled: false
        )

        #expect(state.authorizationStatusTitle == "Temporary")
        #expect(state.allowsNotificationDelivery == true)
        #expect(state.effectiveMorningSummariesEnabled == false)
        #expect(state.effectiveMesoNotificationsEnabled == true)
        #expect(state.effectiveServerNotificationsEnabled == false)
        #expect(state.recoveryActionTitle == nil)
        #expect(state.systemAvailabilityCopy.contains("temporarily"))
    }

    @Test("not determined keeps stored preferences but marks delivery unavailable")
    func notDetermined_marksDeliveryUnavailable() {
        let state = NotificationPreferenceState(
            authorizationStatus: .notDetermined,
            morningSummariesEnabled: true,
            mesoNotificationsEnabled: true,
            serverNotificationsEnabled: false
        )

        #expect(state.authorizationStatusTitle == "Not Set")
        #expect(state.allowsNotificationDelivery == false)
        #expect(state.effectiveMorningSummariesEnabled == false)
        #expect(state.effectiveMesoNotificationsEnabled == false)
        #expect(state.effectiveServerNotificationsEnabled == false)
        #expect(state.recoveryActionTitle == nil)
        #expect(state.systemAvailabilityCopy.contains("saved now"))
    }
}

@Suite("Settings diagnostics support")
struct SettingsDiagnosticsSupportTests {
    @Test("production support copy remains redacted")
    func productionSupportCopyRemainsRedacted() {
        let summary = SettingsSupportSummary(version: "1.2.3 (45)")

        #expect(summary.copyText.contains("1.2.3 (45)"))
        #expect(summary.copyText.contains("redacted"))
        #expect(!summary.copyText.localizedCaseInsensitiveContains("installation"))
        #expect(!summary.copyText.localizedCaseInsensitiveContains("apns"))
        #expect(!summary.copyText.localizedCaseInsensitiveContains("h3"))
    }
}
