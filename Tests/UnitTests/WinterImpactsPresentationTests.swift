import Foundation
import Testing
@testable import SkyAware

struct WinterImpactsPresentationTests {
    private let start = Date(timeIntervalSince1970: 1_800_012_345)
    private let location = WSSIAcceptedAssessment.Location(
        point: .init(latitude: 39, longitude: -105), h3Cell: 1, observedAt: .distantPast
    )

    @Test(arguments: [1, 2, 3], WSSISeverity.allCases)
    func officialOverallThresholds(day: Int, severity: WSSISeverity) {
        let snapshot = project([period(day, .overallImpact, .match(severity))], at: start)
        let eligible = (day == 1 && severity == .moderate)
            || (day <= 2 && [.major, .extreme].contains(severity))
        #expect(snapshot.heroDay?.number == (eligible ? day : nil))
        #expect(snapshot.morningDay?.number == (severity == .winterWeatherArea ? nil : day))
        #expect(snapshot.railDay(winterOwnsHero: false)?.number == day)
    }

    @Test func strongestEligibleOverallWinsAndRailFollowsActualPromotion() {
        let day1 = period(1, .overallImpact, .match(.major))
        let day2 = period(2, .overallImpact, .match(.extreme))
        let day3 = period(3, .overallImpact, .match(.extreme))
        let snapshot = project([day3, day2, day1], at: start)
        #expect(snapshot.heroDay?.number == 2)
        #expect(snapshot.morningDay?.number == 2)
        #expect(snapshot.railDay(winterOwnsHero: true)?.number == 2)
        #expect(snapshot.railDay(winterOwnsHero: false)?.number == 1)

        let tie = project([day2, period(1, .overallImpact, .match(.extreme))], at: start)
        #expect(tie.heroDay?.number == 1)
        #expect(tie.morningDay?.number == 1)
    }

    @Test func mixedIssuancesUseSourceStartForRailAndOverallTies() {
        let newerDay1 = period(1, .overallImpact, .match(.major), startsAfter: 1800)
        let retainedDay2 = period(2, .overallImpact, .match(.major))
        let snapshot = project([newerDay1, retainedDay2], at: start + 1800)
        #expect(snapshot.railDay(winterOwnsHero: false)?.number == 2)
        #expect(snapshot.heroDay?.number == 2)
        #expect(snapshot.morningDay?.number == 2)

        let componentOnly = project([
            newerDay1,
            period(2, .snowAmount, .match(.minor), startsAfter: 900),
            period(2, .iceAccumulation, .match(.minor))
        ], at: start + 1800)
        #expect(componentOnly.railDay(winterOwnsHero: false)?.number == 2)
        #expect(componentOnly.railDay(winterOwnsHero: false)?.railProduct?.product == .iceAccumulation)
        #expect(componentOnly.heroDay?.number == 1)
        #expect(componentOnly.railDay(winterOwnsHero: true)?.number == 1)
    }

    @Test func partialAcceptancePreservesIndependentProductStates() throws {
        let snapshot = project([
            period(1, .overallImpact, .noMatchUnknownCoverage),
            period(1, .snowAmount, .match(.extreme)),
            period(1, .blowingSnow, .confirmedNoImpact)
        ], at: start)

        #expect(snapshot.days.map(\.number) == [1, 2, 3])
        let day = try #require(snapshot.railDay(winterOwnsHero: false))
        #expect(day.number == 1)
        #expect(day.overall.impact == .noMatchUnknownCoverage)
        #expect(day.overall.coverage == .unknown)
        #expect(day.components.map(\.product) == [.snowAmount, .snowLoad, .iceAccumulation, .blowingSnow])
        #expect(day.components.map(\.impact) == [.match(.extreme), .unavailable, .unavailable, .confirmedNoImpact])
        #expect(snapshot.heroDay == nil)
        #expect(snapshot.morningDay == nil)
        #expect(snapshot.days[1].overall.impact == .unavailable)
    }

    @Test func sourceWindowControlsRolloverEvenThroughRefreshFailure() throws {
        let day1 = period(1, .overallImpact, .match(.extreme))
        let day2 = period(2, .overallImpact, .match(.major), startsAfter: 3600)
        let periods = [day1, day2]
        let failure = WSSIAcceptedAssessment.RefreshStatus.manifestFailed(.httpStatus(503, retryAfterSeconds: nil))
        let future = project(periods, at: start, refreshStatus: failure)
        #expect(future.refreshStatus == failure)
        #expect(future.heroDay?.number == 1)
        #expect(future.days[1].overall.validity == .notYetValid)
        #expect(future.days[1].overall.severity == .major)
        let interval = try #require(future.days[1].overall.sourceInterval)
        #expect(interval.start == start + 3600)
        #expect(interval.end == start + 7200)
        #expect(future.days[1].overall.revision == day2.assessment.revision)
        #expect(future.days[1].overall.sourceStatus == .unavailable)

        let rolled = project(periods, at: interval.start, refreshStatus: failure)
        #expect(rolled.days[0].overall.impact == .expired)
        #expect(rolled.days[1].overall.validity == .valid)
        #expect(rolled.heroDay?.number == 2)
        #expect(rolled.railDay(winterOwnsHero: false)?.number == 2)

        let expired = project(periods, at: interval.end)
        #expect(expired.heroDay == nil)
        #expect(expired.morningDay == nil)
        #expect(expired.railDay(winterOwnsHero: false) == nil)
    }

    @Test func newAcceptedRevisionReplacesOnlyItsSlot() {
        let original = period(1, .overallImpact, .match(.minor))
        let new = period(1, .overallImpact, .match(.extreme), revisionNumber: 2)
        let component = period(1, .snowAmount, .match(.minor))
        let before = project([original, component], at: start)
        let after = project([new, component], at: start)
        #expect(before.heroDay == nil)
        #expect(after.heroDay?.overall.revision == new.assessment.revision)
        #expect(after.days[0].components[0].revision == component.assessment.revision)
    }

    @Test func disabledAndGeographicChangesSuppressPreviousLocationEvidence() {
        let accepted = WSSIAcceptedAssessment(
            location: location, periods: [period(1, .overallImpact, .match(.extreme))],
            refreshStatus: .notAttempted
        )
        let moved = WSSIAcceptedAssessment.Location(
            point: .init(latitude: 39.01, longitude: -105), h3Cell: location.h3Cell,
            observedAt: location.observedAt + 60
        )
        let disabled = WinterImpactsPresentation(accepted: accepted, currentLocation: location, enabled: false, at: start)
        let offLocation = WinterImpactsPresentation(accepted: accepted, currentLocation: moved, enabled: true, at: start)
        let noLocation = WinterImpactsPresentation(accepted: accepted, currentLocation: nil, enabled: true, at: start)
        let noCache = WinterImpactsPresentation(accepted: nil, currentLocation: moved, enabled: true, at: start)
        #expect(disabled.days[0].overall.impact == .disabled)
        #expect(offLocation.days[0].overall.impact == .offLocation)
        #expect(noLocation.days[0].overall.impact == .offLocation)
        #expect(noCache.days[0].overall.impact == .unavailable)
        for snapshot in [disabled, offLocation, noLocation, noCache] {
            #expect(snapshot.location == nil)
            #expect(snapshot.refreshStatus == nil)
            #expect(snapshot.days[0].overall.revision == nil)
            #expect(snapshot.heroDay == nil)
            #expect(snapshot.morningDay == nil)
            #expect(snapshot.railDay(winterOwnsHero: false) == nil)
        }
    }

    private func project(
        _ periods: [WSSIAcceptedAssessment.Period], at time: Date,
        refreshStatus: WSSIAcceptedAssessment.RefreshStatus = .notAttempted
    ) -> WinterImpactsPresentation {
        .init(accepted: .init(location: location, periods: periods, refreshStatus: refreshStatus),
              currentLocation: location, enabled: true, at: time)
    }

    private func period(
        _ day: Int, _ product: WSSIProduct, _ impact: WSSIPointAssessment.Impact,
        startsAfter: TimeInterval = 0, revisionNumber: UInt8 = 1
    ) -> WSSIAcceptedAssessment.Period {
        let validFrom = start + startsAfter
        let revision = WSSIAcceptedRevision(
            revision: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(day), 0, 0, revisionNumber)),
            issuedAt: start - 1800, validFrom: validFrom, validTo: validFrom + 3600,
            gisFileDate: nil, gisIngestDate: nil, retrievedAt: start, geometryPath: "/geometry"
        )
        return .init(assessment: .init(
            product: product, day: day, point: location.point, revision: revision,
            validity: startsAfter == 0 ? .valid : .notYetValid,
            sourceStatus: .unavailable, pollHealth: .successful, impact: impact
        ), coverage: .unknown)
    }
}
