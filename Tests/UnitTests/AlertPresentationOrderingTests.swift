import Foundation
import Testing
@testable import SkyAware

@Suite("Alert presentation ordering")
struct AlertPresentationOrderingTests {
    @Test("Orders warnings before watches and mesoscale discussions")
    func ordersWarningsBeforeWatchesAndMesoscaleDiscussions() {
        let now = Date()
        let warning = makeAlert(
            id: "warning",
            title: "Tornado Warning",
            issued: now.addingTimeInterval(-600),
            expires: now.addingTimeInterval(2_400),
            ends: now.addingTimeInterval(3_600)
        )
        let watch = makeAlert(
            id: "watch",
            title: "Severe Thunderstorm Watch",
            issued: now.addingTimeInterval(-300),
            expires: now.addingTimeInterval(1_200),
            ends: now.addingTimeInterval(1_800)
        )
        let meso = makeMeso(
            number: 2001,
            issued: now.addingTimeInterval(-900),
            validEnd: now.addingTimeInterval(1_500)
        )

        let orderedAlerts = AlertPresentationOrdering.ordered([watch, warning], endDate: \.expires)
        let orderedMesos = AlertPresentationOrdering.ordered([meso], endDate: \.validEnd)

        #expect(orderedAlerts.map(\.title) == ["Tornado Warning", "Severe Thunderstorm Watch"])
        #expect(orderedMesos.map(\.title) == ["SPC MD 2001"])
        #expect([orderedAlerts[0].title, orderedAlerts[1].title, orderedMesos[0].title] == [
            "Tornado Warning",
            "Severe Thunderstorm Watch",
            "SPC MD 2001"
        ])
    }

    @Test("Uses end-date and issued tie-breakers within each class")
    func usesEndDateAndIssuedTieBreakersWithinEachClass() {
        let now = Date()
        let earlierIssuedWarning = makeAlert(
            id: "warning-older",
            title: "Tornado Warning",
            issued: now.addingTimeInterval(-1_200),
            expires: now.addingTimeInterval(1_800),
            ends: now.addingTimeInterval(2_400)
        )
        let laterIssuedWarning = makeAlert(
            id: "warning-newer",
            title: "Tornado Warning",
            issued: now.addingTimeInterval(-300),
            expires: now.addingTimeInterval(1_800),
            ends: now.addingTimeInterval(2_400)
        )

        let orderedAlerts = AlertPresentationOrdering.ordered(
            [earlierIssuedWarning, laterIssuedWarning],
            endDate: \.ends
        )
        #expect(orderedAlerts.map(\.id) == ["warning-newer", "warning-older"])

        let earlierIssuedMeso = makeMeso(
            number: 2002,
            issued: now.addingTimeInterval(-1_200),
            validEnd: now.addingTimeInterval(1_800)
        )
        let laterIssuedMeso = makeMeso(
            number: 2003,
            issued: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(1_800)
        )

        let orderedMesos = AlertPresentationOrdering.ordered(
            [earlierIssuedMeso, laterIssuedMeso],
            endDate: \.validEnd
        )
        #expect(orderedMesos.map(\.number) == [2003, 2002])
    }
}

private func makeAlert(
    id: String,
    title: String,
    issued: Date,
    expires: Date,
    ends: Date
) -> AlertDTO {
    AlertDTO(
        id: id,
        messageId: nil,
        currentRevisionSent: nil,
        title: title,
        headline: title,
        issued: issued,
        expires: expires,
        ends: ends,
        messageType: "Alert",
        sender: nil,
        severity: "Severe",
        urgency: "Immediate",
        certainty: "Observed",
        description: title,
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

private func makeMeso(number: Int, issued: Date, validEnd: Date) -> MdDTO {
    MdDTO(
        number: number,
        title: "SPC MD \(number)",
        link: URL(string: "https://example.com/\(number)")!,
        issued: issued,
        validStart: issued,
        validEnd: validEnd,
        areasAffected: "Area",
        summary: "Summary",
        concerning: nil,
        watchProbability: "50",
        threats: nil,
        coordinates: []
    )
}
