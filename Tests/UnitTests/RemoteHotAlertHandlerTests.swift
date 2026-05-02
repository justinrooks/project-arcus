import Foundation
import Testing
import UIKit
@testable import SkyAware

@Suite("Remote hot-alert handler")
struct RemoteHotAlertHandlerTests {
    @Test("background receipt maps to newData when the targeted alert becomes locally available")
    func backgroundReceipt_returnsNewData() async throws {
        let revisionSent = Date(timeIntervalSince1970: 1_776_438_000)
        let alertID = "123e4567-e89b-12d3-a456-426614174001"
        let watch = makeWatch(id: alertID.uppercased(), revisionSent: revisionSent)
        let coordinator = RecordingHomeIngestionCoordinator()
        let alertStore = StubArcusAlertStore(watches: [nil, watch])
        let widgetDriver = RecordingWidgetSnapshotRefreshDriver()
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState,
            widgetSnapshotRefreshDriver: widgetDriver
        )

        let result = await handler.handleRemoteNotification(
            .init(alertID: alertID, revisionSent: revisionSent)
        )

        #expect(result == .newData)
        let request = try #require(await coordinator.requests().first)
        #expect(request.trigger == .remoteHotAlertReceived)
        #expect(request.remoteAlertContext == .init(alertID: alertID, revisionSent: revisionSent))
        #expect(await widgetDriver.refreshCallCount() == 1)
    }

    @Test("background receipt maps to noData when the local alert already matches the pushed revision")
    func backgroundReceipt_returnsNoData() async {
        let revisionSent = Date(timeIntervalSince1970: 1_776_438_000)
        let watch = makeWatch(id: "alert-123", revisionSent: revisionSent)
        let coordinator = RecordingHomeIngestionCoordinator()
        let alertStore = StubArcusAlertStore(watches: [watch, watch])
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState
        )

        let result = await handler.handleRemoteNotification(
            .init(alertID: "alert-123", revisionSent: revisionSent)
        )

        #expect(result == .noData)
    }

    @Test("background receipt maps to failed when the targeted alert is still unavailable after ingestion")
    func backgroundReceipt_returnsFailed() async {
        let coordinator = RecordingHomeIngestionCoordinator()
        let alertStore = StubArcusAlertStore(watches: [nil, nil])
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState
        )

        let result = await handler.handleRemoteNotification(
            .init(
                alertID: "alert-123",
                revisionSent: ISO8601DateFormatter().date(from: "2026-04-17T15:00:00Z")
            )
        )

        #expect(result == .failed)
    }

    @Test("notification open publishes a focus request for the targeted watch after unified ingestion")
    func notificationOpen_publishesFocusRequest() async throws {
        let revisionSent = Date(timeIntervalSince1970: 1_776_438_000)
        let watch = makeWatch(id: "alert-open", revisionSent: revisionSent)
        let coordinator = RecordingHomeIngestionCoordinator()
        let alertStore = StubArcusAlertStore(watches: [watch])
        let widgetDriver = RecordingWidgetSnapshotRefreshDriver()
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState,
            widgetSnapshotRefreshDriver: widgetDriver
        )

        await handler.handleNotificationOpen(
            .init(alertID: "alert-open", revisionSent: revisionSent)
        )

        let request = try #require(await coordinator.requests().first)
        #expect(request.trigger == .remoteHotAlertOpened)

        await MainActor.run {
            #expect(presentationState.focusRequest?.alertID == "alert-open")
            #expect(presentationState.focusRequest?.watch == watch)
        }
        #expect(await widgetDriver.refreshCallCount() == 1)
    }

    @Test("remote notification returns newData when widget snapshot refresh fails")
    func backgroundReceipt_refreshFailureDoesNotChangeApnsResult() async {
        let revisionSent = Date(timeIntervalSince1970: 1_776_438_000)
        let alertID = "123e4567-e89b-12d3-a456-426614174001"
        let watch = makeWatch(id: alertID, revisionSent: revisionSent)
        let coordinator = RecordingHomeIngestionCoordinator()
        let alertStore = StubArcusAlertStore(watches: [nil, watch])
        let widgetDriver = RecordingWidgetSnapshotRefreshDriver(error: TestError.refreshFailed)
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState,
            widgetSnapshotRefreshDriver: widgetDriver
        )

        let result = await handler.handleRemoteNotification(.init(alertID: alertID, revisionSent: revisionSent))

        #expect(result == .newData)
        #expect(await widgetDriver.refreshCallCount() == 1)
    }

    private func makeWatch(id: String, revisionSent: Date) -> WatchRowDTO {
        WatchRowDTO(
            id: id,
            messageId: "urn:\(id)",
            currentRevisionSent: revisionSent,
            title: "Tornado Warning",
            headline: "Immediate action required",
            issued: revisionSent,
            expires: revisionSent.addingTimeInterval(3_600),
            ends: revisionSent.addingTimeInterval(3_600),
            messageType: "Alert",
            sender: "NWS Denver",
            severity: "Extreme",
            urgency: "Immediate",
            certainty: "Observed",
            description: "Test warning",
            instruction: nil,
            response: nil,
            areaSummary: "Denver Metro",
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
}

@Suite("Remote alert widget snapshot refresh driver")
struct RemoteAlertWidgetSnapshotRefreshDriverTests {
    @Test("uses latest projection fallback and active-alert targeted refresh scope")
    func refreshFromLatestProjection_usesFallbackAndTargetedScope() async throws {
        let generatedAt = Date(timeIntervalSince1970: 2_500)
        let projection = makeProjection(
            stormRisk: .enhanced,
            severeRisk: .tornado(probability: 0.2),
            watches: [makeRemoteAlertWatch(id: "alert-1", revisionSent: generatedAt)],
            mesos: []
        )
        let projectionReader = StubLatestProjectionReader(latest: projection)
        let widgetRefresher = RecordingWidgetSnapshotRefresher()
        let driver = RemoteAlertWidgetSnapshotRefreshDriver(
            projectionStore: projectionReader,
            widgetSnapshotRefresher: widgetRefresher
        )

        try await driver.refreshFromLatestProjection(generatedAt: generatedAt)

        let call = try #require(widgetRefresher.lastCall())
        #expect(call.scope == .activeAlertProjection)
        #expect(call.input.generatedAt == generatedAt)
        #expect(call.input.stormRisk == projection.stormRisk)
        #expect(call.input.severeRisk == projection.severeRisk)
        #expect(call.input.watches == projection.activeAlerts)
        #expect(call.input.mesos == projection.activeMesos)
    }

    @Test("does not request widget refresh when latest projection fallback is unavailable")
    func refreshFromLatestProjection_noFallbackProjection_skipsRefresh() async throws {
        let projectionReader = StubLatestProjectionReader(latest: nil)
        let widgetRefresher = RecordingWidgetSnapshotRefresher()
        let driver = RemoteAlertWidgetSnapshotRefreshDriver(
            projectionStore: projectionReader,
            widgetSnapshotRefresher: widgetRefresher
        )

        try await driver.refreshFromLatestProjection(generatedAt: Date(timeIntervalSince1970: 2_600))

        #expect(widgetRefresher.refreshCallCount() == 0)
    }

    private func makeProjection(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        watches: [WatchRowDTO],
        mesos: [MdDTO]
    ) -> HomeProjectionRecord {
        HomeProjectionRecord(
            id: UUID(),
            projectionKey: "key",
            latitude: 39.0,
            longitude: -104.0,
            h3Cell: 123,
            countyCode: "COC001",
            forecastZone: "COZ001",
            fireZone: "COZ201",
            placemarkSummary: "Denver, CO",
            timeZoneId: "America/Denver",
            locationTimestamp: Date(timeIntervalSince1970: 2_000),
            createdAt: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 2_100),
            lastViewedAt: nil,
            weather: nil,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: nil,
            activeAlerts: watches,
            activeMesos: mesos,
            lastHotAlertsLoadAt: Date(timeIntervalSince1970: 2_100),
            lastSlowProductsLoadAt: Date(timeIntervalSince1970: 2_080),
            lastWeatherLoadAt: Date(timeIntervalSince1970: 2_050)
        )
    }
}

private func makeRemoteAlertWatch(id: String, revisionSent: Date) -> WatchRowDTO {
    WatchRowDTO(
        id: id,
        messageId: "urn:\(id)",
        currentRevisionSent: revisionSent,
        title: "Tornado Warning",
        headline: "Immediate action required",
        issued: revisionSent,
        expires: revisionSent.addingTimeInterval(3_600),
        ends: revisionSent.addingTimeInterval(3_600),
        messageType: "Alert",
        sender: "NWS Denver",
        severity: "Extreme",
        urgency: "Immediate",
        certainty: "Observed",
        description: "Test warning",
        instruction: nil,
        response: nil,
        areaSummary: "Denver Metro",
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

private enum TestError: Error {
    case refreshFailed
}

private actor RecordingHomeIngestionCoordinator: HomeIngestionCoordinating {
    private var submittedRequests: [HomeIngestionRequest] = []

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        submittedRequests.append(
            HomeIngestionRequest(
                trigger: trigger,
                locationContext: locationContext,
                remoteAlertContext: remoteAlertContext
            )
        )
    }

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        let request = HomeIngestionRequest(
            trigger: trigger,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        )
        return try await enqueueAndWait(request)
    }

    func enqueue(_ request: HomeIngestionRequest) {
        submittedRequests.append(request)
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        submittedRequests.append(request)
        return .empty
    }

    func requests() -> [HomeIngestionRequest] {
        submittedRequests
    }
}

private actor StubArcusAlertStore: ArcusAlertQuerying {
    private var watches: [WatchRowDTO?]

    init(watches: [WatchRowDTO?]) {
        self.watches = watches
    }

    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        []
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getWatch(id: String) async throws -> WatchRowDTO? {
        guard watches.isEmpty == false else { return nil }
        return watches.removeFirst()
    }
}

private actor RecordingWidgetSnapshotRefreshDriver: RemoteHotAlertHandler.WidgetSnapshotRefreshDriving {
    private let error: Error?
    private var callCount = 0

    init(error: Error? = nil) {
        self.error = error
    }

    func refreshFromLatestProjection(generatedAt: Date) async throws {
        callCount += 1
        if let error {
            throw error
        }
    }

    func refreshCallCount() -> Int {
        callCount
    }
}

private actor StubLatestProjectionReader: LatestHomeProjectionReading {
    private let latest: HomeProjectionRecord?

    init(latest: HomeProjectionRecord?) {
        self.latest = latest
    }

    func latestProjectionForWidgetSnapshotRefresh() throws -> HomeProjectionRecord? {
        latest
    }
}

private final class RecordingWidgetSnapshotRefresher: WidgetSnapshotRefreshing, @unchecked Sendable {
    struct Call: Sendable {
        let scope: WidgetSnapshotChangeScope
        let input: WidgetSnapshotRefreshInput
    }

    private let lock = NSLock()
    private var calls: [Call] = []

    func refresh(scope: WidgetSnapshotChangeScope, input: WidgetSnapshotRefreshInput) throws {
        lock.lock()
        defer { lock.unlock() }
        calls.append(.init(scope: scope, input: input))
    }

    func refreshCallCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return calls.count
    }

    func lastCall() -> Call? {
        lock.lock()
        defer { lock.unlock() }
        return calls.last
    }
}
