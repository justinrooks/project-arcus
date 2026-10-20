import Foundation
import Testing
@testable import SkyAware

@Suite("Accepted weather awareness contract")
struct WeatherAwarenessResultTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Accepted quiet risks and alerts differ from missing values")
    func quietAndUnavailable() throws {
        let quiet = try assessment(record())
        #expect(quiet.risks.storm == .allClear)
        #expect(quiet.risks.severe == .allClear)
        #expect(quiet.risks.fire == .clear)
        #expect(quiet.riskFreshness == .current)
        #expect(quiet.hasCurrentQuietAlerts)

        let missing = try assessment(record(storm: nil, severe: nil, fire: nil, alertAge: nil))
        #expect(missing.riskFreshness == .unavailable)
        #expect(missing.risks.storm == nil)
        #expect(missing.alertFreshness == .unavailable)
        #expect(!missing.hasCurrentQuietAlerts)
    }

    @Test("Risk and alert freshness age independently at exact boundaries", arguments: [true, false])
    func independentFreshness(staleRisk: Bool) throws {
        let result = try assessment(record(
            riskAge: staleRisk ? WeatherAwarenessResult.riskMaximumAge : 0,
            alertAge: staleRisk ? 0 : WeatherAwarenessResult.alertMaximumAge
        ))
        #expect(result.riskFreshness == (staleRisk ? .stale : .current))
        #expect(result.alertFreshness == (staleRisk ? .current : .stale))
        #expect(result.hasCurrentQuietAlerts == staleRisk)
        #expect(result.risks.assessedAt == now.addingTimeInterval(
            staleRisk ? -WeatherAwarenessResult.riskMaximumAge : 0
        ))
    }

    @Test("Partial risk preserves canonical categories and missing domains")
    func partialRisk() throws {
        let result = try assessment(record(storm: .enhanced, severe: .tornado(probability: 0.15), fire: nil))
        #expect(result.risks.storm == .enhanced)
        #expect(result.risks.severe == .tornado(probability: 0.15))
        #expect(result.risks.fire == nil)
        #expect(result.risks.source == .stormPredictionCenter)
        #expect(result.risks.convectiveSourceToken == "accepted-source")
    }

    @Test("Missing or future acceptance times never inherit the record update time", arguments: [nil, -60.0])
    func invalidAcceptanceTimes(age: Double?) throws {
        let result = try assessment(record(riskAge: age, alertAge: age, alerts: [alert("live")]))
        #expect(result.riskFreshness == .unavailable)
        #expect(result.alertFreshness == .unavailable)
        #expect(result.events.isEmpty)
        #expect(!result.hasCurrentQuietAlerts)
    }

    @Test("Expiry, future starts and official alert hierarchy are evaluated at read time")
    func eventSelection() throws {
        let snapshot = WeatherAwarenessSnapshot(accepted: record(alerts: [
            alert("watch", title: "Tornado Watch"),
            alert("expired", endOffset: 0),
            alert("future", startOffset: 60),
            alert("warning", title: "Tornado Warning")
        ], mesos: [meso(2, endOffset: 0), meso(1), meso(3, startOffset: 60)]))
        let result = try #require(assessment(WeatherAwarenessResult.select(snapshot, now: now)))
        #expect(result.events.map(\.id) == ["warning", "watch", "1"])
        #expect(result.events.map(\.source) == [.nationalWeatherService, .nationalWeatherService, .stormPredictionCenter])
        #expect(!result.hasCurrentQuietAlerts)
        #expect(result.events.first?.issuedAt == now.addingTimeInterval(-60))

        let later = try #require(assessment(WeatherAwarenessResult.select(
            snapshot, now: now.addingTimeInterval(WeatherAwarenessResult.alertMaximumAge)
        )))
        #expect(later.events.isEmpty)
        #expect(later.alertFreshness == .stale)
        #expect(!later.hasCurrentQuietAlerts)
    }

    @Test("Stale alerts retain time-valid events without claiming current quiet")
    func stalePopulatedAlerts() throws {
        let result = try assessment(record(alertAge: 1_800, alerts: [alert("warning")]))
        #expect(result.alertFreshness == .stale)
        #expect(result.events.map(\.id) == ["warning"])
        #expect(!result.hasCurrentQuietAlerts)
    }

    @Test("NWS activity ends at the earlier CAP expiration or event end; quiet requires current coverage",
          arguments: [true, false], [Optional(0.0), Optional(1_800.0), nil])
    func nwsTerminalBoundary(expiresFirst: Bool, alertAge: Double?) throws {
        let snapshot = WeatherAwarenessSnapshot(accepted: record(
            alertAge: alertAge,
            alerts: [alert("warning", endOffset: expiresFirst ? 600 : 30,
                           expiresOffset: expiresFirst ? 30 : 600)]
        ))
        for offset in [29.0, 30.0, 31.0] {
            let result = try #require(assessment(.select(snapshot, now: now.addingTimeInterval(offset))))
            let isActive = alertAge != nil && offset < 30
            #expect(result.events.map(\.id) == (isActive ? ["warning"] : []))
            #expect(result.hasCurrentQuietAlerts == (alertAge == 0 && offset >= 30))
        }
    }

    @Test("Missing cache, corrupt cache, missing location and scope mismatch are explicit")
    func unavailableResults() {
        #expect(WeatherAwarenessResult.select(nil, now: now) == .unavailable(.noCache))
        #expect(WeatherAwarenessResult.unavailable(.corruptCache) != .unavailable(.noCache))
        #expect(WeatherAwarenessResult.select(
            WeatherAwarenessSnapshot(accepted: record(key: " ")), now: now
        ) == .unavailable(.missingAssessedLocation))
        #expect(WeatherAwarenessResult.select(
            WeatherAwarenessSnapshot(accepted: record()), expectedProjectionKey: "other-location", now: now
        ) == .unavailable(.locationMismatch))
    }

    @Test("Snapshot survives Codable and actor transfer without geometry or coordinate fields")
    func valueBoundary() async throws {
        let snapshot = WeatherAwarenessSnapshot(accepted: record(label: "  Bennett, CO  "))
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WeatherAwarenessSnapshot.self, from: encoded)
        let transferred = await Task.detached { WeatherAwarenessResult.select(decoded, now: now) }.value
        let result = try #require(assessment(transferred))
        #expect(decoded == snapshot)
        #expect(result.location.displayLabel == "Bennett, CO")
        #expect(result.location.projectionKey == "assessed-location")
        #expect(result.location.assessedAt == now.addingTimeInterval(-600))
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(!json.contains("latitude"))
        #expect(!json.contains("longitude"))
        #expect(!json.contains("geometry"))
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(WeatherAwarenessSnapshot.self, from: Data("{}".utf8))
        }
        #expect(WeatherAwarenessSnapshot(accepted: record(label: " ")).location?.displayLabel == nil)
    }

    private func assessment(_ record: HomeProjectionRecord) throws -> WeatherAwarenessResult.Assessment {
        try #require(assessment(.select(WeatherAwarenessSnapshot(accepted: record), now: now)))
    }

    private func assessment(_ result: WeatherAwarenessResult) -> WeatherAwarenessResult.Assessment? {
        guard case .assessment(let value) = result else { return nil }
        return value
    }

    private func record(
        key: String = "assessed-location", label: String? = "Bennett, CO",
        storm: StormRiskLevel? = .allClear, severe: SevereWeatherThreat? = .allClear,
        fire: FireRiskLevel? = .clear, riskAge: Double? = 0, alertAge: Double? = 0,
        alerts: [AlertDTO] = [], mesos: [MdDTO] = []
    ) -> HomeProjectionRecord {
        .init(
            id: UUID(), projectionKey: key, latitude: 39, longitude: -104, h3Cell: 1,
            countyCode: "CO001", forecastZone: nil, fireZone: "COZ001", placemarkSummary: label,
            timeZoneId: nil, locationTimestamp: now.addingTimeInterval(-600),
            createdAt: now, updatedAt: now, lastViewedAt: nil, weather: nil,
            stormRisk: storm, severeRisk: severe, fireRisk: fire, activeAlerts: alerts, activeMesos: mesos,
            lastHotAlertsLoadAt: alertAge.map { now.addingTimeInterval(-$0) },
            lastSlowProductsLoadAt: riskAge.map { now.addingTimeInterval(-$0) }, lastWeatherLoadAt: now,
            convectiveSourceToken: "accepted-source"
        )
    }

    private func alert(
        _ id: String, title: String = "Severe Thunderstorm Warning",
        startOffset: Double = -60, endOffset: Double = 600, expiresOffset: Double = 30
    ) -> AlertDTO {
        .init(
            id: id, messageId: nil, title: title, headline: title,
            issued: now.addingTimeInterval(startOffset), expires: now.addingTimeInterval(expiresOffset),
            ends: now.addingTimeInterval(endOffset), messageType: "Alert", sender: nil,
            severity: "Severe", urgency: "Immediate", certainty: "Observed", description: "",
            instruction: nil, response: nil, areaSummary: "", tornadoDetection: nil,
            tornadoDamageThreat: nil, maxWindGust: nil, maxHailSize: nil, windThreat: nil,
            hailThreat: nil, thunderstormDamageThreat: nil, flashFloodDetection: nil, flashFloodDamageThreat: nil
        )
    }

    private func meso(_ number: Int, startOffset: Double = -60, endOffset: Double = 600) -> MdDTO {
        .init(
            number: number, title: "SPC MD \(number)", link: URL(fileURLWithPath: "/unused"),
            issued: now.addingTimeInterval(-60), validStart: now.addingTimeInterval(startOffset),
            validEnd: now.addingTimeInterval(endOffset), areasAffected: "", summary: "",
            watchProbability: "Unknown", threats: nil, coordinates: []
        )
    }
}
