import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("MapData freshness filtering", .serialized)
struct MapDataFreshnessRepoTests {
    @Test("Fire map returns only newest issuance per risk level")
    func fireMapReturnsNewestIssuancePerRiskLevel() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [FireRisk.self]) }
        try await MainActor.run { try TestStore.reset(FireRisk.self, in: container) }

        let repo = FireRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 9, 0)
        let expires = makeUTCDate(2026, 3, 1, 21, 0)
        let olderIssue = makeUTCDate(2026, 3, 1, 9, 0)
        let newerIssue = makeUTCDate(2026, 3, 1, 11, 0)
        let level5Issue = makeUTCDate(2026, 3, 1, 10, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: olderIssue,
                    expires: expires,
                    valid: valid,
                    riskLevel: 8,
                    label: "Critical",
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: []
                )
            )
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: newerIssue,
                    expires: expires,
                    valid: valid,
                    riskLevel: 8,
                    label: "Critical",
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: []
                )
            )
            context.insert(
                FireRisk(
                    product: "FireRH",
                    issued: level5Issue,
                    expires: expires,
                    valid: valid,
                    riskLevel: 5,
                    label: "Elevated",
                    stroke: "#CCCC00",
                    fill: "#333300",
                    polygons: []
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.count == 2)

        let byLevel = Dictionary(uniqueKeysWithValues: results.map { ($0.riskLevel, $0) })
        #expect(byLevel[8]?.issued == newerIssue)
        #expect(byLevel[5]?.issued == level5Issue)
    }

    @Test("Categorical map returns newest issuance per storm level")
    func stormMapReturnsNewestIssuancePerLevel() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [StormRisk.self]) }
        try await MainActor.run { try TestStore.reset(StormRisk.self, in: container) }

        let repo = StormRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 8, 0)
        let expires = makeUTCDate(2026, 3, 1, 22, 0)
        let olderIssue = makeUTCDate(2026, 3, 1, 8, 0)
        let newerIssue = makeUTCDate(2026, 3, 1, 11, 30)
        let slightIssue = makeUTCDate(2026, 3, 1, 10, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                StormRisk(
                    riskLevel: .enhanced,
                    issued: olderIssue,
                    expires: expires,
                    valid: valid,
                    stroke: "#111111",
                    fill: "#222222",
                    polygons: []
                )
            )
            context.insert(
                StormRisk(
                    riskLevel: .enhanced,
                    issued: newerIssue,
                    expires: expires,
                    valid: valid,
                    stroke: "#333333",
                    fill: "#444444",
                    polygons: []
                )
            )
            context.insert(
                StormRisk(
                    riskLevel: .slight,
                    issued: slightIssue,
                    expires: expires,
                    valid: valid,
                    stroke: "#555555",
                    fill: "#666666",
                    polygons: []
                )
            )
            try context.save()
        }

        let results = try await repo.getLatestMapData(asOf: asOf)
        #expect(results.count == 2)

        let byLevel = Dictionary(uniqueKeysWithValues: results.map { ($0.riskLevel, $0) })
        #expect(byLevel[.enhanced]?.issued == newerIssue)
        #expect(byLevel[.slight]?.issued == slightIssue)
    }

    @Test("Severe map returns newest issuance per type and probability bucket")
    func severeMapReturnsNewestIssuancePerBucket() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [SevereRisk.self]) }
        try await MainActor.run { try TestStore.reset(SevereRisk.self, in: container) }

        let repo = SevereRiskRepo(modelContainer: container)
        let asOf = makeUTCDate(2026, 3, 1, 12, 0)
        let valid = makeUTCDate(2026, 3, 1, 7, 0)
        let expires = makeUTCDate(2026, 3, 1, 23, 0)
        let olderIssue = makeUTCDate(2026, 3, 1, 8, 0)
        let newerIssue = makeUTCDate(2026, 3, 1, 11, 0)

        try await MainActor.run {
            let context = ModelContext(container)
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: olderIssue,
                    valid: valid,
                    expires: expires,
                    dn: 15,
                    stroke: "#AA0000",
                    fill: "#110000",
                    polygons: [],
                    label: "0.15"
                )
            )
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .percent(0.15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: newerIssue,
                    valid: valid,
                    expires: expires,
                    dn: 15,
                    stroke: "#BB0000",
                    fill: "#220000",
                    polygons: [],
                    label: "0.15"
                )
            )
            context.insert(
                SevereRisk(
                    type: .tornado,
                    probability: .significant(15),
                    threatLevel: .tornado(probability: 0.15),
                    issued: newerIssue,
                    valid: valid,
                    expires: expires,
                    dn: 15,
                    stroke: "#CC0000",
                    fill: "#330000",
                    polygons: [],
                    label: "SIGN"
                )
            )
            try context.save()
        }

        let results = try await repo.getSevereRiskShapes(asOf: asOf)
        #expect(results.count == 2)

        let percent15 = results.first { $0.type == .tornado && $0.probabilities == .percent(0.15) }
        #expect(percent15?.fill == "#220000")

        let significant15 = results.first { $0.type == .tornado && $0.probabilities == .significant(15) }
        #expect(significant15?.fill == "#330000")
    }
}

private func makeUTCDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(
        from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}
