import Foundation
import Testing
@testable import SkyAware

@Suite("RemoteNotificationRegistrar")
struct RemoteNotificationRegistrarTests {
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
}
