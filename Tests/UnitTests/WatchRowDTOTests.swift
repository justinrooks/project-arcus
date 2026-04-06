import Testing
@testable import SkyAware
import Foundation

@Suite("WatchRowDTO")
struct WatchRowDTOTests {
    @Test("Recognizes update message types case-insensitively")
    func recognizesUpdateMessageType() {
        let now = Date()
        let sut = WatchRowDTO(
            id: "watch-1",
            messageId: "urn:test",
            title: "Tornado Watch",
            headline: "Updated watch",
            issued: now,
            expires: now,
            ends: now,
            messageType: "Update",
            sender: "NWS",
            severity: "Extreme",
            urgency: "Immediate",
            certainty: "Observed",
            description: "Test",
            instruction: nil,
            response: nil,
            areaSummary: "Denver Metro"
        )

        #expect(sut.isUpdateMessage)
    }
}
