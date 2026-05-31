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

    @Test
    func composerShowsPercentWhenProbabilityIsNumeric() {
        let composer = MesoComposer()
        let event = NotificationEvent(
            kind: .mesoNotification,
            key: "meso:2026-01-02-1234",
            payload: [
                "mesoId": 1234,
                "watchProbability": 30.0,
                "watchProbabilityText": "30",
                "placeMark": "Oklahoma City, OK"
            ]
        )

        let message = composer.compose(event)
        #expect(message.title == "Mesoscale Discussion for Oklahoma City, OK")
        #expect(message.subtitle == "Watch issuance chance: 30%")
    }

    @Test
    func composerShowsWatchPotentialNotSpecifiedWhenProbabilityMissing() {
        let composer = MesoComposer()
        let event = NotificationEvent(
            kind: .mesoNotification,
            key: "meso:2026-01-02-1234",
            payload: [
                "mesoId": 1234,
                "watchProbabilityText": "Unknown",
                "placeMark": "Norman, OK"
            ]
        )

        let message = composer.compose(event)
        #expect(message.subtitle == "Watch potential not specified")
    }

    @Test
    func composerBuildsWindAndHailSummary() {
        let composer = MesoComposer()
        let event = NotificationEvent(
            kind: .mesoNotification,
            key: "meso:2026-01-02-1234",
            payload: [
                "mesoId": 1234,
                "watchProbability": 35.0,
                "watchProbabilityText": "35",
                "placeMark": "Bennett, CO",
                "threats": MDThreats(
                    peakWindMPH: 35,
                    hailRangeInches: 2.0,
                    tornadoStrength: nil
                )
            ]
        )

        let message = composer.compose(event)
        #expect(message.body == "Main concerns: damaging wind and large hail. Gusts near 35 mph; hail up to 2\".")
    }

    @Test
    func composerUsesFallbackWhenThreatDetailsAreSparse() {
        let composer = MesoComposer()
        let event = NotificationEvent(
            kind: .mesoNotification,
            key: "meso:2026-01-02-1234",
            payload: [
                "mesoId": 1234,
                "watchProbability": 35.0,
                "watchProbabilityText": "35",
                "placeMark": "Bennett, CO"
            ]
        )

        let message = composer.compose(event)
        #expect(message.body == "SPC is monitoring storms near your area. Open SkyAware for the full discussion.")
    }

    @Test
    func composerNeverShowsUnknownInUserFacingCopy() {
        let composer = MesoComposer()
        let event = NotificationEvent(
            kind: .mesoNotification,
            key: "meso:2026-01-02-1234",
            payload: [
                "mesoId": 1234,
                "watchProbabilityText": "Unknown",
                "placeMark": "Unknown",
                "threats": MDThreats(
                    peakWindMPH: nil,
                    hailRangeInches: nil,
                    tornadoStrength: "unknown"
                )
            ]
        )

        let message = composer.compose(event)
        #expect(message.title == "Mesoscale Discussion for your area")
        #expect(message.subtitle == "Watch potential not specified")
        #expect(message.body == "SPC is monitoring storms near your area. Open SkyAware for the full discussion.")
        #expect(message.title.localizedCaseInsensitiveContains("unknown") == false)
        #expect(message.subtitle.localizedCaseInsensitiveContains("unknown") == false)
        #expect(message.body.localizedCaseInsensitiveContains("unknown") == false)
    }
}

// MARK: - Test Doubles

actor InMemoryMesoStore: NotificationStateStoring {
    private var stamp: String?
    
    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}
