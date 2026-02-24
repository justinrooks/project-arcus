import Foundation
import Testing
@testable import SkyAware

@Suite("RemoteNotificationRegistrar")
struct RemoteNotificationRegistrarTests {
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
