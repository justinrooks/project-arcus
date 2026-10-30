//
//  RemoteHotAlertHandler.swift
//  SkyAware
//
//  Created by Codex on 4/17/26.
//

import Foundation
import Observation
import OSLog
import UIKit
import ArcusCore

enum RemoteNotificationContext: Sendable, Equatable {
    case nwsAlert(HomeRemoteAlertContext)
    case mesoscaleDiscussion(productID: String)

    init?(userInfo: [AnyHashable: Any]) {
        if let payload = HomeRemoteAlertContext.sharedPayload(in: userInfo),
           payload.productKind == .mesoscaleDiscussion, let productID = payload.resourceID {
            self = .mesoscaleDiscussion(productID: productID)
        } else if let alert = HomeRemoteAlertContext(userInfo: userInfo) {
            self = .nwsAlert(alert)
        } else {
            return nil
        }
    }
}

struct RemoteAlertFocusRequest: Identifiable, Hashable, Sendable {
    let id = UUID()
    let alertID: String
    let alert: AlertDTO?
    var meso: MdDTO? = nil
    var isMeso: Bool = false
    var openStartedAt: ContinuousClock.Instant? = nil
}

protocol RemoteAlertResolving: ArcusAlertQuerying {
    func resolveNotificationAlert(_ context: HomeRemoteAlertContext) async throws -> AlertDTO?
}

@Observable
@MainActor
final class RemoteAlertPresentationState {
    var focusRequest: RemoteAlertFocusRequest?

    func present(alertID: String, alert: AlertDTO?, openStartedAt: ContinuousClock.Instant? = nil) {
        focusRequest = RemoteAlertFocusRequest(alertID: alertID, alert: alert, openStartedAt: openStartedAt)
    }

    func presentMeso(productID: String, meso: MesoscaleDiscussionPayload?, openStartedAt: ContinuousClock.Instant) {
        focusRequest = RemoteAlertFocusRequest(
            alertID: productID, alert: nil, meso: meso.map(MdDTO.init(payload:)),
            isMeso: true, openStartedAt: openStartedAt
        )
    }

    func clearFocusRequest(id: RemoteAlertFocusRequest.ID?) {
        guard let id, focusRequest?.id == id else { return }
        focusRequest = nil
    }
}

/// Carries canonical targeted acceptance through the coordinator's existing owner boundary.
enum RemoteAlertAcceptance {
    @TaskLocal static var observer: (@Sendable (AlertDTO?) async -> Void)?
}

/// One caller's lifetime. The watchdog never awaits the work it cancels: providers may ignore cancellation.
actor RemoteNotificationReceipt {
    let executionContext: BackgroundRefreshExecutionContext
    private let now: @Sendable () -> ContinuousClock.Instant
    private let sleepUntil: @Sendable (ContinuousClock.Instant) async throws -> Void
    private var continuation: CheckedContinuation<UIBackgroundFetchResult, Never>?
    private var result: UIBackgroundFetchResult?
    private var acceptedResult: UIBackgroundFetchResult?
    private var work: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
#if DEBUG
    private var workExited = false
    private var workExitWaiters: [CheckedContinuation<Void, Never>] = []

    func waitForWorkExitForTesting() async {
        if !workExited { await withCheckedContinuation { workExitWaiters.append($0) } }
    }
#endif

    init(
        start: ContinuousClock.Instant = .now,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { .now },
        sleepUntil: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
            try await ContinuousClock().sleep(until: $0)
        }
    ) {
        // Application policy: 25 seconds total, with two seconds reserved for completion.
        executionContext = .init(budget: .init(
            start: start, completionDeadline: start + .seconds(25), finalizationReserve: .seconds(2)
        ))
        self.now = now
        self.sleepUntil = sleepUntil
    }

    func run(
        _ operation: @escaping @Sendable () async -> UIBackgroundFetchResult
    ) async -> UIBackgroundFetchResult {
        if Task.isCancelled { finish() }
        if let result { return result }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            work = Task {
                let value = await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                    await HTTPExecutionMode.$current.withValue(.background) {
                        await operation()
                    }
                }
                finish(value)
#if DEBUG
                workExited = true
                let waiters = workExitWaiters
                workExitWaiters = []
                waiters.forEach { $0.resume() }
#endif
            }
            watchdog = Task {
                do {
                    try await sleepUntil(executionContext.budget.workDeadline)
                    finish()
                } catch { /* Normal completion cancels the watchdog. */ }
            }
        }
    }

    func checkActive() throws {
        try Task.checkCancellation()
        guard result == nil, executionContext.budget.remainingWork(at: now()) > .zero else {
            throw CancellationError()
        }
    }

    func recordAccepted(_ value: UIBackgroundFetchResult) {
        guard result == nil, executionContext.budget.remainingWork(at: now()) > .zero else { return }
        if value != .failed || acceptedResult == nil { acceptedResult = value }
    }

    func finish(_ value: UIBackgroundFetchResult? = nil) {
        guard result == nil else { return }
        result = acceptedResult ?? value ?? .failed
        work?.cancel()
        watchdog?.cancel()
        work = nil
        watchdog = nil
        if let result { continuation?.resume(returning: result) }
        continuation = nil
    }
}

actor RemoteHotAlertHandler {
    protocol WidgetSnapshotRefreshDriving: Sendable {
        func refreshFromLatestProjection(generatedAt: Date) async throws
    }

    private let coordinator: any HomeIngestionCoordinating
    private let arcusAlerts: any RemoteAlertResolving
    private let arcusMesos: (any RemoteMesoResolving)?
    private var latestOpenID: UUID?
    private let presentationState: RemoteAlertPresentationState
    private let widgetSnapshotRefreshDriver: (any WidgetSnapshotRefreshDriving)?
    private let allowsBackgroundIngestion: @Sendable () async -> Bool
    private let logger: Logger

    init(
        coordinator: any HomeIngestionCoordinating,
        arcusAlerts: any RemoteAlertResolving,
        presentationState: RemoteAlertPresentationState,
        arcusMesos: (any RemoteMesoResolving)? = nil,
        widgetSnapshotRefreshDriver: (any WidgetSnapshotRefreshDriving)? = nil,
        allowsBackgroundIngestion: @escaping @Sendable () async -> Bool = { true },
        logger: Logger = .notificationsRemote
    ) {
        self.coordinator = coordinator
        self.arcusAlerts = arcusAlerts
        self.arcusMesos = arcusMesos
        self.presentationState = presentationState
        self.widgetSnapshotRefreshDriver = widgetSnapshotRefreshDriver
        self.allowsBackgroundIngestion = allowsBackgroundIngestion
        self.logger = logger
    }

    func handleRemoteNotification(
        _ context: RemoteNotificationContext,
        receipt: RemoteNotificationReceipt = RemoteNotificationReceipt()
    ) async -> UIBackgroundFetchResult {
        await withTaskCancellationHandler {
            await receipt.run { await self.receive(context, receipt: receipt) }
        } onCancel: {
            Task { await receipt.finish() }
        }
    }

    private func receive(
        _ context: RemoteNotificationContext, receipt: RemoteNotificationReceipt
    ) async -> UIBackgroundFetchResult {
        do {
            try await receipt.checkActive()
            guard await allowsBackgroundIngestion() else { return .failed }
            try await receipt.checkActive()
            switch context {
            case .nwsAlert(let alert):
                let previous = try await arcusAlerts.getAlert(id: alert.alertID)
                try await receipt.checkActive()
                if alert.fetchResult(before: previous, after: previous) == .noData {
                    await receipt.recordAccepted(.noData)
                }
                try await RemoteAlertAcceptance.$observer.withValue({ latest in
                    await receipt.recordAccepted(alert.fetchResult(before: previous, after: latest))
                }) {
                    _ = try await coordinator.enqueueAndWait(
                        .remoteHotAlertReceived, remoteAlertContext: alert
                    )
                }
                try await receipt.checkActive()
                let latest = try await arcusAlerts.getAlert(id: alert.alertID)
                try await receipt.checkActive()
                await receipt.recordAccepted(alert.fetchResult(before: previous, after: latest))
            case .mesoscaleDiscussion(let productID):
                guard let arcusMesos else { return .failed }
                let before = try await arcusMesos.acceptedNotificationMeso(productID: productID)
                try await receipt.checkActive()
                guard let accepted = try await arcusMesos.resolveNotificationMeso(productID: productID) else {
                    return .failed
                }
                try await receipt.checkActive()
                await receipt.recordAccepted(before == accepted ? .noData : .newData)
                try await receipt.checkActive()
                _ = try await coordinator.enqueueAndWait(.remoteHotAlertReceived)
            }
            try await receipt.checkActive()
            await refreshWidgetSnapshotAfterRemoteAlertIngestion()
            try await receipt.checkActive()
            return .noData // The accepted product result is retained by the receipt.
        } catch {
            logger.error("Remote hot-alert receipt did not finish")
            return .failed
        }
    }

    func handleNotificationOpen(_ context: RemoteNotificationContext) async {
        switch context {
        case .nwsAlert(let alert):
            await handleNotificationOpen(alert)
        case .mesoscaleDiscussion(let productID):
            let openID = UUID()
            latestOpenID = openID
            let startedAt = ContinuousClock.now
            let meso: MesoscaleDiscussionPayload?
            do {
                meso = try await arcusMesos?.resolveNotificationMeso(productID: productID)
            } catch {
                logger.error("Remote meso open resolution failed")
                meso = nil
            }
            guard latestOpenID == openID, !Task.isCancelled else { return }
            await presentationState.presentMeso(productID: productID, meso: meso, openStartedAt: startedAt)
        }
    }

    func handleRemoteNotification(_ remoteAlertContext: HomeRemoteAlertContext) async -> UIBackgroundFetchResult {
        await handleRemoteNotification(.nwsAlert(remoteAlertContext))
    }

    func handleNotificationOpen(_ remoteAlertContext: HomeRemoteAlertContext) async {
        let openID = UUID()
        latestOpenID = openID
        let startedAt = ContinuousClock.now
        logger.info("Notification open started")
        let alertDTO: AlertDTO?
        do {
            alertDTO = try await arcusAlerts.resolveNotificationAlert(remoteAlertContext)
        } catch {
            logger.error("Remote hot-alert open resolution failed")
            alertDTO = nil
        }
        guard latestOpenID == openID, !Task.isCancelled else { return }
        await presentationState.present(
            alertID: remoteAlertContext.alertID,
            alert: alertDTO,
            openStartedAt: startedAt
        )
        logger.info("Notification open focus published elapsed=\(String(describing: startedAt.duration(to: .now)), privacy: .public)")
    }

    private func refreshWidgetSnapshotAfterRemoteAlertIngestion() async {
        guard let widgetSnapshotRefreshDriver else {
            return
        }

        do {
            try await widgetSnapshotRefreshDriver.refreshFromLatestProjection(generatedAt: Date())
        } catch {
            logger.error(
                "Remote hot-alert widget snapshot refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

protocol LatestHomeProjectionReading: Actor {
    func latestProjectionForWidgetSnapshotRefresh() throws -> HomeProjectionRecord?
    func latestWidgetPublication() throws -> WidgetSnapshotPublication?
}

extension LatestHomeProjectionReading {
    func latestWidgetPublication() throws -> WidgetSnapshotPublication? {
        try latestProjectionForWidgetSnapshotRefresh().map { WidgetSnapshotPublication(projection: $0) }
    }
}

extension HomeProjectionStore: LatestHomeProjectionReading {}

actor RemoteAlertWidgetSnapshotRefreshDriver: RemoteHotAlertHandler.WidgetSnapshotRefreshDriving {
    private let projectionStore: any LatestHomeProjectionReading
    private let widgetSnapshotRefresher: any WidgetSnapshotRefreshing

    init(
        projectionStore: any LatestHomeProjectionReading,
        widgetSnapshotRefresher: any WidgetSnapshotRefreshing
    ) {
        self.projectionStore = projectionStore
        self.widgetSnapshotRefresher = widgetSnapshotRefresher
    }

#if DEBUG
    private var publicationCheckpointForTesting: (@Sendable () async -> Void)?

    func setPublicationCheckpointForTesting(_ checkpoint: (@Sendable () async -> Void)?) {
        publicationCheckpointForTesting = checkpoint
    }
#endif

    func refreshFromLatestProjection(generatedAt: Date) async throws {
        guard let publication = try await projectionStore.latestWidgetPublication(),
              publication.projection.lastHotAlertsLoadAt != nil else {
            return
        }

#if DEBUG
        await publicationCheckpointForTesting?()
#endif
        try Task.checkCancellation()
        try widgetSnapshotRefresher.refresh(
            scope: .activeAlertProjection,
            input: .init(publication: publication, generatedAt: generatedAt)
        )
    }
}

extension HomeRemoteAlertContext {
    private static let referenceDateEpochOffset: TimeInterval = 978_307_200

    init?(userInfo: [AnyHashable: Any]) {
        let hasTypedIdentity = userInfo[HotAlertAPNsPayload.productKindKey] != nil
            || userInfo[HotAlertAPNsPayload.resourceIDKey] != nil

        if hasTypedIdentity {
            guard let payload = Self.sharedPayload(in: userInfo),
                  payload.productKind == .nwsAlert,
                  let alertID = payload.resolvedAlertID else { return nil }
            self.init(alertID: alertID, revisionSent: payload.revisionSent)
            return
        }

        if let payload = Self.sharedPayload(in: userInfo),
           let alertID = payload.resolvedAlertID {
            self.init(
                alertID: alertID,
                revisionSent: payload.revisionSent
            )
            return
        }

        guard let alertID = Self.identifier(in: userInfo) else {
            return nil
        }

        self.init(
            alertID: alertID,
            revisionSent: Self.date(in: userInfo)
        )
    }

    func fetchResult(
        before previousAlert: AlertDTO?,
        after latestAlert: AlertDTO?
    ) -> UIBackgroundFetchResult {
        guard let latestAlert, latestAlert.matches(self) else {
            return .failed
        }

        if let previousAlert, previousAlert.matches(self), previousAlert.matchesRevision(of: latestAlert) {
            return .noData
        }

        return .newData
    }

    private static func identifier(in userInfo: [AnyHashable: Any]) -> String? {
        for key in ["arcusAlertId", "alertID", "alertId", "seriesID", "seriesId", "eventKey"] {
            guard let value = userInfo[key] else { continue }
            if let stringValue = normalizedString(from: value) {
                return stringValue
            }
        }

        return nil
    }

    private static func date(in userInfo: [AnyHashable: Any]) -> Date? {
        for key in ["revisionSent", "currentRevisionSent", "sent", "revisionTimestamp", "timestamp"] {
            guard let value = userInfo[key] else { continue }
            if let date = normalizedDate(from: value) {
                return date
            }
        }

        return nil
    }

    private static func normalizedString(from value: Any) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedDate(from value: Any) -> Date? {
        if let date = value as? Date {
            return date
        }

        if let number = value as? NSNumber {
            return dateFromNumericPayloadValue(number.doubleValue)
        }

        if let timeInterval = value as? TimeInterval {
            return dateFromNumericPayloadValue(timeInterval)
        }

        if let integer = value as? Int {
            return dateFromNumericPayloadValue(TimeInterval(integer))
        }

        guard let string = normalizedString(from: value) else {
            return nil
        }

        if let epoch = TimeInterval(string) {
            return dateFromNumericPayloadValue(epoch)
        }

        return ISO8601DateFormatter().date(from: string)
    }

    private static func dateFromNumericPayloadValue(_ value: TimeInterval) -> Date {
        var seconds = value > 10_000_000_000 ? value / 1_000 : value
        if seconds > 0, seconds < referenceDateEpochOffset {
            seconds += referenceDateEpochOffset
        }
        return Date(timeIntervalSince1970: seconds)
    }

    fileprivate static func sharedPayload(in userInfo: [AnyHashable: Any]) -> HotAlertAPNsPayload? {
        let dictionary = userInfo.reduce(into: [String: Any]()) { result, entry in
            guard let key = entry.key as? String else { return }
            result[key] = entry.value
        }

        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HotAlertAPNsPayload.self, from: data)
    }
}

private extension AlertDTO {
    func matches(_ remoteAlertContext: HomeRemoteAlertContext) -> Bool {
        guard ArcusAlertIdentifier.canonical(id) == ArcusAlertIdentifier.canonical(remoteAlertContext.alertID) else {
            return false
        }

        guard let revisionSent = remoteAlertContext.revisionSent else {
            return true
        }

        guard let currentRevisionSent else { return false }
        return currentRevisionSent >= revisionSent
    }

    func matchesRevision(of other: AlertDTO) -> Bool {
        messageId == other.messageId &&
        currentRevisionSent == other.currentRevisionSent
    }
}
