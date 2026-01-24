import Testing
@testable import SkyAware
import CoreLocation
import Foundation

@Suite("Watch Notification")
struct WatchNotificationTests {
    private let centralTime: TimeZone = TimeZone(secondsFromGMT: -6 * 3600)!

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tz: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = DateComponents(calendar: calendar, timeZone: tz, year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }

    private func makeWatch(
        id: String = "abc123",
        messageId: String = "abc123",
        issued: Date,
        expires: Date,
        ends: Date,
        sender: String = "NWS Norman",
        severity: String = "Severe",
        urgency: String = "Immediate",
        certainty: String = "Observed",
        title: String = "Tornado Watch",
        headline: String = "Severe threat",
        area: String = "Oklahoma"
    ) -> WatchRowDTO {
        WatchRowDTO(
            id: id,
            messageId: messageId,
            title: title,
            headline: headline,
            issued: issued,
            expires: expires,
            ends: ends,
            messageType: "Alert",
            sender: sender,
            severity: severity,
            urgency: urgency,
            certainty: certainty,
            description: "",
            instruction: nil,
            response: nil,
            areaSummary: area
        )
    }

    @Test
    func ruleCreatesEventForActiveWatch() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 15, tz: centralTime)
        let watch = makeWatch(
            issued: now.addingTimeInterval(-3_600),
            expires: now.addingTimeInterval(10_800),
            ends: now.addingTimeInterval(11_500)
        )

        let ctx = WatchContext(
            now: now,
            localTZ: centralTime,
            location: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            placeMark: "Oklahoma City, OK",
            watches: [watch]
        )

        let rule = WatchRule()
        do {
            let event = try #require(rule.evaluate(ctx))
            
            #expect(event.kind == .watchNotification)
            #expect(event.key == "watch:2026-01-02-\(watch.id)")
            #expect(event.payload["watchId"] as? String == watch.id)
            #expect(event.payload["localDay"] as? String == "2026-01-02")
            #expect(event.payload["headline"] as? String == watch.headline)
            #expect(event.payload["placeMark"] as? String == "Oklahoma City, OK")
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test
    func ruleSkipsExpiredOrOldWatches() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 15, tz: centralTime)
        let expired = makeWatch(
            issued: now.addingTimeInterval(-7_200),
            expires: now.addingTimeInterval(-3_600),
            ends: now.addingTimeInterval(-3_200)
        )
        let tooOld = makeWatch(
            id: "old",
            issued: now.addingTimeInterval(-26 * 3_600),
            expires: now.addingTimeInterval(1_800),
            ends: now.addingTimeInterval(1_900)
        )

        let ctx = WatchContext(
            now: now,
            localTZ: centralTime,
            location: CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
            placeMark: "Norman, OK",
            watches: [expired, tooOld]
        )

        let rule = WatchRule()
        let event = rule.evaluate(ctx)

        #expect(event == nil)
    }

    @Test
    func gateBlocksDuplicateEvents() async {
        let gate = WatchGate(store: InMemoryNotificationStore())
        let event = NotificationEvent(
            kind: .watchNotification,
            key: "watch:2026-01-02-abc123",
            payload: [
                "localDay": "2026-01-02",
                "watchId": "abc123"
            ]
        )

        let firstPass = await gate.allow(event, now: .now)
        let secondPass = await gate.allow(event, now: .now)

        #expect(firstPass == true)
        #expect(secondPass == false)
    }
}

// MARK: - Test Doubles

actor InMemoryNotificationStore: NotificationStateStoring {
    private var stamp: String?

    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}
