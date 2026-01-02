import Testing
@testable import SkyAware
import CoreLocation
import Foundation

@Suite("Meso Notification")
struct MesoNotificationTests {
    private let centralTime: TimeZone = TimeZone(secondsFromGMT: -6 * 3600)!
    
    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tz: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = DateComponents(calendar: calendar, timeZone: tz, year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
    
    private func makeMeso(
        number: Int = 1234,
        issued: Date,
        validEnd: Date,
        title: String = "Mesoscale Discussion",
        summary: String = "Potential severe storms",
        watchProbability: String = "30",
        place: String = "Oklahoma"
    ) -> MdDTO {
        MdDTO(
            number: number,
            title: title,
            link: URL(string: "https://example.com/md")!,
            issued: issued,
            validStart: issued,
            validEnd: validEnd,
            areasAffected: place,
            summary: summary,
            watchProbability: watchProbability,
            threats: nil,
            coordinates: []
        )
    }
    
    @Test
    func ruleCreatesEventForActiveMeso() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 15, tz: centralTime)
        let meso = makeMeso(
            issued: now.addingTimeInterval(-3_600),
            validEnd: now.addingTimeInterval(3_600)
        )
        
        let ctx = MesoContext(
            now: now,
            localTZ: centralTime,
            location: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            placeMark: "Oklahoma City, OK",
            mesos: [meso]
        )
        
        let rule = MesoRule()
        do {
            let event = try #require(rule.evaluate(ctx))
            
            #expect(event.kind == .mesoNotification)
            #expect(event.key == "meso:2026-01-02-\(meso.number)")
            #expect(event.payload["mesoId"] as? Int == meso.number)
            #expect(event.payload["localDay"] as? String == "2026-01-02")
            #expect(event.payload["placeMark"] as? String == "Oklahoma City, OK")
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }
    }
    
    @Test
    func ruleSkipsExpiredMesos() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 15, tz: centralTime)
        let expired = makeMeso(
            issued: now.addingTimeInterval(-7_200),
            validEnd: now.addingTimeInterval(-3_600)
        )
        
        let ctx = MesoContext(
            now: now,
            localTZ: centralTime,
            location: CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
            placeMark: "Norman, OK",
            mesos: [expired]
        )
        
        let rule = MesoRule()
        let event = rule.evaluate(ctx)
        
        #expect(event == nil)
    }
    
    @Test
    func gateBlocksDuplicateEvents() async {
        let gate = MesoGate(store: InMemoryMesoStore())
        let event = NotificationEvent(
            kind: .mesoNotification,
            key: "meso:2026-01-02-1234",
            payload: [
                "localDay": "2026-01-02",
                "mesoId": 1234
            ]
        )
        
        let firstPass = await gate.allow(event, now: .now)
        let secondPass = await gate.allow(event, now: .now)
        
        #expect(firstPass == true)
        #expect(secondPass == false)
    }
}

// MARK: - Test Doubles

actor InMemoryMesoStore: NotificationStateStore {
    private var stamp: String?
    
    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}
