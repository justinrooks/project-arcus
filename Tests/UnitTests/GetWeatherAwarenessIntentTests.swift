import Foundation
import Testing
@testable import SkyAware

@Suite("Get weather awareness response")
struct GetWeatherAwarenessIntentTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Current official warning or watch leads the response and risks remain supporting context",
          arguments: ["Tornado Warning", "Tornado Watch"])
    func warningOrWatchHasPriority(_ title: String) throws {
        let assessment = assessment(
            alertsAssessedAt: now.addingTimeInterval(-60),
            events: [event("Mesoscale Discussion", source: .stormPredictionCenter),
                     event(title)],
            riskAssessedAt: now.addingTimeInterval(-300)
        )

        let response = WeatherAwarenessResponseFormatter.make(from: assessment)

        #expect(response.contains("Latest accepted assessment for Parker, Colorado; current location was not checked."))
        let alertPosition = try #require(response.range(of: "Active official alert: \(title).")?.lowerBound)
        let riskPosition = try #require(response.range(of: "Current risk assessment")?.lowerBound)
        #expect(alertPosition < riskPosition)
        #expect(response.contains("Also 1 event: 1 SPC mesoscale discussion"))
    }

    @Test("Current warning summaries count every additional active alert by source")
    func currentWarningsCountAdditionalEvents() {
        let response = WeatherAwarenessResponseFormatter.make(from: assessment(
            alertsAssessedAt: now,
            events: [event("Tornado Warning"), event("Severe Thunderstorm Warning"), event("Flash Flood Warning")]
        ))

        #expect(response.contains("Active official alert: Tornado Warning."))
        #expect(response.contains("Also 2 events: 2 NWS alerts"))
    }

    @Test("Current mixed and mesoscale-only summaries count omitted events")
    func currentMixedAndMesoOnlyCounts() {
        let mixed = WeatherAwarenessResponseFormatter.make(from: assessment(
            alertsAssessedAt: now,
            events: [event("Tornado Warning"), event("Mesoscale Discussion", source: .stormPredictionCenter),
                     event("Winter Weather Advisory")]
        ))
        let mesoscaleOnly = WeatherAwarenessResponseFormatter.make(from: assessment(
            alertsAssessedAt: now,
            events: [event("Mesoscale Discussion 1", source: .stormPredictionCenter),
                     event("Mesoscale Discussion 2", source: .stormPredictionCenter)]
        ))

        #expect(mixed.contains("Also 2 events: 1 NWS alert and 1 SPC mesoscale discussion"))
        #expect(mesoscaleOnly.contains("Local SPC mesoscale discussion: Mesoscale Discussion 1."))
        #expect(mesoscaleOnly.contains("Also 1 event: 1 SPC mesoscale discussion"))
    }

    @Test("Current non-warning NWS event is identified and single events need no overflow count")
    func currentNonWarningAndSingleEvent() {
        let response = WeatherAwarenessResponseFormatter.make(from: assessment(
            alertsAssessedAt: now,
            events: [event("Winter Weather Advisory")]
        ))

        #expect(response.contains("Local NWS alert: Winter Weather Advisory."))
        #expect(!response.contains("Also"))
    }

    @Test("Only a current accepted empty alert assessment supports a quiet statement")
    func acceptedQuietAlerts() {
        let currentQuiet = assessment(alertsAssessedAt: now, events: [])
        let unavailableAlerts = assessment(alertsAssessedAt: nil, events: [])
        let staleAlerts = assessment(alertsAssessedAt: now.addingTimeInterval(-3_600), events: [])

        #expect(WeatherAwarenessResponseFormatter.make(from: currentQuiet).contains("none of its alerts are still valid now"))
        #expect(!WeatherAwarenessResponseFormatter.make(from: unavailableAlerts).contains("still valid now"))
        #expect(!WeatherAwarenessResponseFormatter.make(from: staleAlerts).contains("still valid now"))
    }

    @Test("Stale alert assessments do not present retained warnings as active")
    func staleWarningIsNotCurrent() {
        let result = assessment(
            alertsAssessedAt: now.addingTimeInterval(-3_600),
            events: [event("Tornado Warning")]
        )

        let response = WeatherAwarenessResponseFormatter.make(from: result)

        #expect(response.contains("alert check") && response.contains("is stale"))
        #expect(response.contains("included Tornado Warning"))
        #expect(response.contains("Last accepted snapshot included 1 event: 1 NWS alert; current alert status is unverified."))
        #expect(!response.contains("Active official alert"))
    }

    @Test("Unavailable alert coverage does not report accepted event counts")
    func unavailableAlertsDoNotReportCounts() {
        let result = assessment(
            alertsAssessedAt: nil,
            events: [event("Tornado Warning"), event("Mesoscale Discussion", source: .stormPredictionCenter)]
        )

        let response = WeatherAwarenessResponseFormatter.make(from: result)

        #expect(response.contains("Local alert information is unavailable."))
        #expect(!response.contains("snapshot"))
        #expect(!response.contains("2 events"))
    }

    @Test("Risk-only data never claims alerts are quiet and stale risk stays marked stale")
    func riskOnlyAndStaleRisk() {
        let result = assessment(
            alertsAssessedAt: nil,
            events: [],
            riskAssessedAt: now.addingTimeInterval(-9 * 60 * 60)
        )

        let response = WeatherAwarenessResponseFormatter.make(from: result)

        #expect(response.contains("Local alert information is unavailable."))
        #expect(response.contains("Risk assessment from"))
        #expect(response.contains("is stale"))
        #expect(!response.contains("No active local alerts"))
    }

    @Test("Current alerts remain useful when risk details are unavailable")
    func alertOnlyAssessment() {
        let result = assessment(alertsAssessedAt: now, events: [event("Severe Thunderstorm Warning")])
        let response = WeatherAwarenessResponseFormatter.make(from: result)

        #expect(response.contains("Active official alert: Severe Thunderstorm Warning."))
        #expect(response.contains("Risk information is unavailable."))
    }

    @Test("Unavailable snapshots and location mismatches stay explicit")
    func unavailableResults() {
        #expect(WeatherAwarenessResponseFormatter.make(from: .unavailable(.noCache))
            .contains("saved weather awareness assessment is unavailable"))
        #expect(WeatherAwarenessResponseFormatter.make(from: .unavailable(.corruptCache))
            .contains("saved weather awareness assessment is unavailable"))
        #expect(WeatherAwarenessResponseFormatter.make(from: .unavailable(.readFailure))
            .contains("saved weather awareness assessment is unavailable"))
        #expect(WeatherAwarenessResponseFormatter.make(from: .unavailable(.locationMismatch))
            .contains("does not match the requested location"))
        #expect(WeatherAwarenessResponseFormatter.make(from: .unavailable(.missingAssessedLocation))
            .contains("no saved assessment location"))
    }

    private func assessment(
        alertsAssessedAt: Date?,
        events: [WeatherAwarenessSnapshot.Event],
        riskAssessedAt: Date? = nil
    ) -> WeatherAwarenessResult {
        .assessment(.init(
            location: .init(projectionKey: "cell-1", displayLabel: "Parker, Colorado", assessedAt: now),
            risks: .init(
                source: .stormPredictionCenter,
                convectiveSourceToken: nil,
                assessedAt: riskAssessedAt,
                storm: .slight,
                severe: .tornado(probability: 0.1),
                fire: .elevated
            ),
            riskFreshness: freshness(riskAssessedAt, maximumAge: WeatherAwarenessResult.riskMaximumAge),
            alertsAssessedAt: alertsAssessedAt,
            alertFreshness: freshness(alertsAssessedAt, maximumAge: WeatherAwarenessResult.alertMaximumAge),
            events: events
        ))
    }

    private func freshness(_ date: Date?, maximumAge: TimeInterval) -> WeatherAwarenessResult.Freshness {
        guard let date, date <= now else { return .unavailable }
        return now.timeIntervalSince(date) < maximumAge ? .current : .stale
    }

    private func event(
        _ title: String,
        source: WeatherAwarenessSnapshot.Source = .nationalWeatherService
    ) -> WeatherAwarenessSnapshot.Event {
        .init(
            source: source,
            id: title,
            title: title,
            issuedAt: now.addingTimeInterval(-600),
            validStart: now.addingTimeInterval(-600),
            validEnd: now.addingTimeInterval(3_600)
        )
    }
}
