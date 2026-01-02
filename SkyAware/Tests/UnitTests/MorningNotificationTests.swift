import Testing
@testable import SkyAware
import Foundation

@Suite("Morning Notification")
struct MorningNotificationTests {
    private let centralTime: TimeZone = TimeZone(secondsFromGMT: -6 * 3600)!
    
    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tz: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = DateComponents(calendar: calendar, timeZone: tz, year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
    
    @Test
    func ruleCreatesEventInWindow() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
        let issue = now.addingTimeInterval(-2 * 3600)
        
        let ctx = MorningContext(
            now: now,
            lastConvectiveIssue: issue,
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.3),
            placeMark: "Oklahoma City, OK"
        )
        
        let rule = AmRangeLocalRule(window: 7..<11)
        do {
            let event = try #require(rule.evaluate(ctx))
            
            #expect(event.kind == .morningOutlook)
            #expect(event.key == "morning:2026-01-02")
            #expect(event.payload["localDay"] as? String == "2026-01-02")
            #expect(event.payload["issue"] as? Date == issue)
            #expect(event.payload["placeMark"] as? String == "Oklahoma City, OK")
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }
    
    @Test
    func ruleSkipsOutsideWindow() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 13, tz: centralTime)
        
        let ctx = MorningContext(
            now: now,
            lastConvectiveIssue: now.addingTimeInterval(-2 * 3600),
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.3),
            placeMark: "Oklahoma City, OK"
        )
        
        let rule = AmRangeLocalRule(window: 7..<11)
        let event = rule.evaluate(ctx)
        
        #expect(event == nil)
    }
    
    @Test
    func ruleSkipsStaleIssue() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
        let issue = now.addingTimeInterval(-26 * 3600)
        
        let ctx = MorningContext(
            now: now,
            lastConvectiveIssue: issue,
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.3),
            placeMark: "Oklahoma City, OK"
        )
        
        let rule = AmRangeLocalRule(window: 7..<11)
        let event = rule.evaluate(ctx)
        
        #expect(event == nil)
    }
    
    @Test
    func gateBlocksDuplicateEvents() async {
        let gate = MorningGate(store: InMemoryMorningStore())
        let event = NotificationEvent(
            kind: .morningOutlook,
            key: "morning:2026-01-02",
            payload: [
                "localDay": "2026-01-02"
            ]
        )
        
        let firstPass = await gate.allow(event, now: .now)
        let secondPass = await gate.allow(event, now: .now)
        
        #expect(firstPass == true)
        #expect(secondPass == false)
    }
}

// MARK: - Test Doubles

actor InMemoryMorningStore: MorningStateStore {
    private var stamp: String?
    
    func lastMorningStamp() async -> String? { stamp }
    func setLastMorningStamp(_ stamp: String) async { self.stamp = stamp }
}
