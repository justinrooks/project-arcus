import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Alert Eligibility")
struct StormSetupAlertEligibilityTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test("only active approved event titles qualify", arguments: [
        ("Severe Thunderstorm Watch", true),
        ("Severe Thunderstorm Warning", true),
        ("Tornado Watch", true),
        ("Tornado Warning", true),
        ("  tornado warning  ", true),
        ("Air Quality Alert", false),
        ("Flash Flood Warning", false),
        ("Winter Storm Warning", false),
        ("Unknown", false),
        ("", false)
    ])
    func exactTitleEligibility(title: String, expected: Bool) {
        #expect(StormSetupAlertEligibility.qualifies(makeAlert(title: title), now: now) == expected)
    }

    @Test("validity interval is issued-inclusive and end-exclusive")
    func validityIntervalEligibility() {
        #expect(StormSetupAlertEligibility.qualifies(
            makeAlert(title: "Tornado Warning", issued: now, ends: now.addingTimeInterval(1)),
            now: now
        ))
        #expect(StormSetupAlertEligibility.qualifies(
            makeAlert(title: "Tornado Warning", issued: now.addingTimeInterval(1), ends: now.addingTimeInterval(2)),
            now: now
        ) == false)
        #expect(StormSetupAlertEligibility.qualifies(
            makeAlert(title: "Tornado Warning", issued: now.addingTimeInterval(-1), ends: now),
            now: now
        ) == false)
        #expect(StormSetupAlertEligibility.qualifies(
            makeAlert(title: "Tornado Warning", issued: now.addingTimeInterval(-2), ends: now.addingTimeInterval(-1)),
            now: now
        ) == false)
    }

    private func makeAlert(
        title: String,
        issued: Date? = nil,
        ends: Date? = nil
    ) -> AlertDTO {
        let resolvedIssued = issued ?? now.addingTimeInterval(-1)
        let resolvedEnds = ends ?? now.addingTimeInterval(1)

        return AlertDTO(
            id: UUID().uuidString,
            messageId: nil,
            currentRevisionSent: nil,
            title: title,
            headline: title,
            issued: resolvedIssued,
            expires: resolvedEnds,
            ends: resolvedEnds,
            messageType: "Alert",
            sender: nil,
            severity: "Severe",
            urgency: "Immediate",
            certainty: "Observed",
            description: "Alert",
            instruction: nil,
            response: nil,
            areaSummary: "Area",
            geometryData: nil,
            tornadoDetection: nil,
            tornadoDamageThreat: nil,
            maxWindGust: nil,
            maxHailSize: nil,
            windThreat: nil,
            hailThreat: nil,
            thunderstormDamageThreat: nil,
            flashFloodDetection: nil,
            flashFloodDamageThreat: nil
        )
    }
}
