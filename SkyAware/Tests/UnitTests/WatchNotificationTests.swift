import CoreLocation
import Foundation
import Testing
@testable import SkyAware

@Suite("Watch notifications")
struct WatchNotificationTests {
    private let centralTime = TimeZone(secondsFromGMT: -6 * 3_600)!

    @Test("rule creates an event for the newest active watch")
    func ruleCreatesEventForNewestActiveWatch() throws {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 15, tz: centralTime)
        let olderWatch = makeWatch(
            id: "older",
            issued: now.addingTimeInterval(-7_200),
            ends: now.addingTimeInterval(7_200)
        )
        let newerWatch = makeWatch(
            id: "newer",
            issued: now.addingTimeInterval(-1_800),
            ends: now.addingTimeInterval(7_200)
        )

        let event = try #require(
            WatchRule().evaluate(
                WatchContext(
                    now: now,
                    localTZ: centralTime,
                    location: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
                    placeMark: "Oklahoma City, OK",
                    watches: [olderWatch, newerWatch]
                )
            )
        )

        #expect(event.kind == .watchNotification)
        #expect(event.key == "watch:newer")
        #expect(event.payload["watchId"] as? String == "newer")
        #expect(event.payload["title"] as? String == newerWatch.title)
    }

    @Test("gate blocks duplicate watch notifications")
    func gateBlocksDuplicateWatchNotifications() async {
        let gate = WatchGate(store: InMemoryNotificationStore())
        let event = NotificationEvent(
            kind: .watchNotification,
            key: "watch:abc123",
            payload: ["watchId": "abc123"]
        )

        let firstPass = await gate.allow(event, now: .now)
        let secondPass = await gate.allow(event, now: .now)

        #expect(firstPass)
        #expect(secondPass == false)
    }

    @Test("gate remembers more than the most recent watch id")
    func gateRemembersMoreThanMostRecentWatchID() async {
        let gate = WatchGate(store: InMemoryNotificationStore())
        let firstEvent = NotificationEvent(
            kind: .watchNotification,
            key: "watch:first",
            payload: ["watchId": "first"]
        )
        let secondEvent = NotificationEvent(
            kind: .watchNotification,
            key: "watch:second",
            payload: ["watchId": "second"]
        )

        #expect(await gate.allow(firstEvent, now: .now))
        #expect(await gate.allow(secondEvent, now: .now))
        #expect(await gate.allow(firstEvent, now: .now) == false)
    }

    @Test("engine sends a single notification for a new watch")
    func engineSendsNotificationForNewWatch() async {
        let sender = RecordingSender()
        let engine = WatchEngine(
            rule: WatchRule(),
            gate: WatchGate(store: InMemoryNotificationStore()),
            composer: WatchComposer(),
            sender: sender
        )

        let didSend = await engine.run(
            ctx: .init(
                now: .now,
                localTZ: centralTime,
                location: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
                placeMark: "Oklahoma City, OK"
            ),
            watches: [makeWatch(id: "abc123", issued: .now.addingTimeInterval(-300), ends: .now.addingTimeInterval(3_600))]
        )

        #expect(didSend)
        let sent = await sender.sent()
        #expect(sent.count == 1)
        #expect(sent[0].id == "watch:abc123")
    }

    @Test("background location change syncs hot feeds and sends a watch notification")
    func backgroundLocationChangeSyncsHotFeedsAndSendsWatchNotification() async {
        let sender = RecordingSender()
        let watchEngine = WatchEngine(
            rule: WatchRule(),
            gate: WatchGate(store: InMemoryNotificationStore()),
            composer: WatchComposer(),
            sender: sender
        )
        let context = Self.makeContext()
        let resolver = FakeLocationContextResolver(context: context)
        let spc = FakeBackgroundSpcProvider()
        let arcus = FakeBackgroundArcusProvider(watches: [makeWatch(id: "watch-1", issued: .now.addingTimeInterval(-300), ends: .now.addingTimeInterval(3_600))])
        let handler = BackgroundLocationChangeHandler(
            locationContextResolver: resolver,
            spcSync: spc,
            spcRisk: spc,
            arcusSync: arcus,
            arcusQuery: arcus,
            watchEngine: watchEngine
        )

        await handler.handleLocationChange()

        #expect(await spc.syncMesoscaleCount() == 1)
        #expect(await arcus.syncCount() == 1)
        #expect(await spc.activeMesosQueryCount() == 1)
        #expect(await arcus.queryCount() == 1)
        #expect((await sender.sent()).count == 1)
    }

    @Test("duplicate background location changes do not re-notify the same watch")
    func duplicateBackgroundLocationChangesDoNotRenotifySameWatch() async {
        let sender = RecordingSender()
        let watchEngine = WatchEngine(
            rule: WatchRule(),
            gate: WatchGate(store: InMemoryNotificationStore()),
            composer: WatchComposer(),
            sender: sender
        )
        let context = Self.makeContext()
        let resolver = FakeLocationContextResolver(context: context)
        let spc = FakeBackgroundSpcProvider()
        let arcus = FakeBackgroundArcusProvider(watches: [makeWatch(id: "watch-1", issued: .now.addingTimeInterval(-300), ends: .now.addingTimeInterval(3_600))])
        let handler = BackgroundLocationChangeHandler(
            locationContextResolver: resolver,
            spcSync: spc,
            spcRisk: spc,
            arcusSync: arcus,
            arcusQuery: arcus,
            watchEngine: watchEngine
        )

        await handler.handleLocationChange()
        await handler.handleLocationChange()

        #expect((await sender.sent()).count == 1)
        #expect(await spc.syncMesoscaleCount() == 2)
        #expect(await arcus.syncCount() == 2)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tz: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = DateComponents(
            calendar: calendar,
            timeZone: tz,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components)!
    }

    private func makeWatch(
        id: String,
        issued: Date,
        ends: Date,
        title: String = "Tornado Watch",
        headline: String = "Severe storms are possible"
    ) -> WatchRowDTO {
        WatchRowDTO(
            id: id,
            messageId: id,
            title: title,
            headline: headline,
            issued: issued,
            expires: ends,
            ends: ends,
            messageType: "Alert",
            sender: "NWS Norman",
            severity: "Severe",
            urgency: "Immediate",
            certainty: "Observed",
            description: "",
            instruction: nil,
            response: nil,
            areaSummary: "Oklahoma"
        )
    }

    private static func makeContext() -> LocationContext {
        let coordinates = CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164)
        let snapshot = LocationSnapshot(
            coordinates: coordinates,
            timestamp: .now,
            accuracy: 50,
            placemarkSummary: "Oklahoma City, OK",
            h3Cell: 123_456
        )
        let grid = GridPointSnapshot(
            nwsId: "OUN/10,20",
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            gridId: "OUN",
            gridX: 10,
            gridY: 20,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Oklahoma City",
            state: "OK",
            timeZoneId: "America/Chicago",
            radarStationId: nil,
            forecastZone: "OKZ025",
            countyCode: "OKC109",
            fireZone: "OKZ025",
            countyLabel: "Oklahoma",
            fireZoneLabel: "Central Oklahoma"
        )
        return LocationContext(snapshot: snapshot, h3Cell: 123_456, grid: grid)
    }
}

actor InMemoryNotificationStore: NotificationStateStoring {
    private var stamp: String?

    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}

actor RecordingSender: NotificationSending {
    struct SentNotification: Sendable {
        let title: String
        let body: String
        let subtitle: String
        let id: String
    }

    private var notifications: [SentNotification] = []

    func send(title: String, body: String, subtitle: String, id: String) async {
        notifications.append(.init(title: title, body: body, subtitle: subtitle, id: id))
    }

    func sent() -> [SentNotification] {
        notifications
    }
}

private actor FakeBackgroundSpcProvider: SpcSyncing, SpcRiskQuerying {
    private var syncMesoscaleCalls = 0
    private var activeMesosQueries = 0

    func sync() async {}
    func syncMapProducts() async {}
    func syncTextProducts() async {}
    func syncConvectiveOutlooks() async {}

    func syncMesoscaleDiscussions() async {
        syncMesoscaleCalls += 1
    }

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        .allClear
    }

    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        .allClear
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        activeMesosQueries += 1
        return []
    }

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel {
        .clear
    }

    func syncMesoscaleCount() -> Int { syncMesoscaleCalls }
    func activeMesosQueryCount() -> Int { activeMesosQueries }
}

private actor FakeBackgroundArcusProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private let watches: [WatchRowDTO]
    private var syncCalls = 0
    private var queryCalls = 0

    init(watches: [WatchRowDTO]) {
        self.watches = watches
    }

    func sync(context: LocationContext) async {
        syncCalls += 1
    }

    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        queryCalls += 1
        return watches
    }

    func syncCount() -> Int { syncCalls }
    func queryCount() -> Int { queryCalls }
}

private struct FakeLocationContextResolver: LocationContextResolving {
    let context: LocationContext

    func prepareCurrentContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async throws -> LocationContext {
        context
    }

    func resolveContext(
        from snapshot: LocationSnapshot,
        maximumAcceptedLocationAge: TimeInterval?,
        placemarkTimeout: Double
    ) async throws -> LocationContext {
        context
    }
}
