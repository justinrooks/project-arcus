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
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState
        )

        let result = await handler.handleRemoteNotification(
            .init(alertID: alertID, revisionSent: revisionSent)
        )

        #expect(result == .newData)
        let request = try #require(await coordinator.requests().first)
        #expect(request.trigger == .remoteHotAlertReceived)
        #expect(request.remoteAlertContext == .init(alertID: alertID, revisionSent: revisionSent))
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
        let presentationState = await MainActor.run { RemoteAlertPresentationState() }
        let handler = RemoteHotAlertHandler(
            coordinator: coordinator,
            arcusAlerts: alertStore,
            presentationState: presentationState
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
