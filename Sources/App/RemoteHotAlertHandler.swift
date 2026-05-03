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

struct RemoteAlertFocusRequest: Identifiable, Equatable, Sendable {
    let id = UUID()
    let alertID: String
    let watch: WatchRowDTO?
}

@Observable
@MainActor
final class RemoteAlertPresentationState {
    var focusRequest: RemoteAlertFocusRequest?

    func present(alertID: String, watch: WatchRowDTO?) {
        focusRequest = RemoteAlertFocusRequest(alertID: alertID, watch: watch)
    }
}

actor RemoteHotAlertHandler {
    protocol WidgetSnapshotRefreshDriving: Sendable {
        func refreshFromLatestProjection(generatedAt: Date) async throws
    }

    private let coordinator: any HomeIngestionCoordinating
    private let arcusAlerts: any ArcusAlertQuerying
    private let presentationState: RemoteAlertPresentationState
    private let widgetSnapshotRefreshDriver: (any WidgetSnapshotRefreshDriving)?
    private let logger: Logger

    init(
        coordinator: any HomeIngestionCoordinating,
        arcusAlerts: any ArcusAlertQuerying,
        presentationState: RemoteAlertPresentationState,
        widgetSnapshotRefreshDriver: (any WidgetSnapshotRefreshDriving)? = nil,
        logger: Logger = .notificationsRemote
    ) {
        self.coordinator = coordinator
        self.arcusAlerts = arcusAlerts
        self.presentationState = presentationState
        self.widgetSnapshotRefreshDriver = widgetSnapshotRefreshDriver
        self.logger = logger
    }

    func handleRemoteNotification(_ remoteAlertContext: HomeRemoteAlertContext) async -> UIBackgroundFetchResult {
        do {
            let previousWatch = try await arcusAlerts.getWatch(id: remoteAlertContext.alertID)
            _ = try await coordinator.enqueueAndWait(
                .remoteHotAlertReceived,
                locationContext: nil,
                remoteAlertContext: remoteAlertContext
            )
            await refreshWidgetSnapshotAfterRemoteAlertIngestion()
            let latestWatch = try await arcusAlerts.getWatch(id: remoteAlertContext.alertID)
            return remoteAlertContext.fetchResult(before: previousWatch, after: latestWatch)
        } catch {
            logger.error("Remote hot-alert receipt failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    func handleNotificationOpen(_ remoteAlertContext: HomeRemoteAlertContext) async {
        do {
            _ = try await coordinator.enqueueAndWait(
                .remoteHotAlertOpened,
                locationContext: nil,
                remoteAlertContext: remoteAlertContext
            )
            await refreshWidgetSnapshotAfterRemoteAlertIngestion()
            let watch = try await arcusAlerts.getWatch(id: remoteAlertContext.alertID)
            await MainActor.run {
                presentationState.present(alertID: remoteAlertContext.alertID, watch: watch)
            }
        } catch {
            logger.error("Remote hot-alert open failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                presentationState.present(alertID: remoteAlertContext.alertID, watch: nil)
            }
        }
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

    func refreshFromLatestProjection(generatedAt: Date) async throws {
        guard let latestProjection = try await projectionStore.latestProjectionForWidgetSnapshotRefresh() else {
            return
        }

        try widgetSnapshotRefresher.refresh(
            scope: .activeAlertProjection,
            input: .init(
                generatedAt: generatedAt,
                stormRisk: latestProjection.stormRisk,
                severeRisk: latestProjection.severeRisk,
                watches: latestProjection.activeAlerts,
                mesos: latestProjection.activeMesos,
                locationSummary: latestProjection.placemarkSummary
            )
        )
    }
}

extension HomeRemoteAlertContext {
    init?(userInfo: [AnyHashable: Any]) {
        guard let alertID = Self.identifier(in: userInfo) else {
            return nil
        }

        self.init(
            alertID: alertID,
            revisionSent: Self.date(in: userInfo)
        )
    }

    func fetchResult(
        before previousWatch: WatchRowDTO?,
        after latestWatch: WatchRowDTO?
    ) -> UIBackgroundFetchResult {
        guard let latestWatch, latestWatch.matches(self) else {
            return .failed
        }

        if let previousWatch, previousWatch.matches(self), previousWatch.matchesRevision(of: latestWatch) {
            return .noData
        }

        return .newData
    }

    private static func identifier(in userInfo: [AnyHashable: Any]) -> String? {
        for key in ["alertID", "alertId", "seriesID", "seriesId", "eventKey"] {
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

        if let timeInterval = value as? TimeInterval {
            return normalizedDate(from: timeInterval)
        }

        if let integer = value as? Int {
            return normalizedDate(from: TimeInterval(integer))
        }

        guard let string = normalizedString(from: value) else {
            return nil
        }

        if let epoch = TimeInterval(string) {
            return normalizedDate(from: epoch)
        }

        return ISO8601DateFormatter().date(from: string)
    }

    private static func normalizedDate(from epoch: TimeInterval) -> Date {
        let seconds = epoch > 10_000_000_000 ? epoch / 1_000 : epoch
        return Date(timeIntervalSince1970: seconds)
    }
}

private extension WatchRowDTO {
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

    func matchesRevision(of other: WatchRowDTO) -> Bool {
        messageId == other.messageId &&
        currentRevisionSent == other.currentRevisionSent
    }
}
