//
//  HomeProjectionStore.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import ArcusCore
import OSLog
import SwiftData

enum RiskProfileDimension: String, Sendable {
    case storm
    case severe
    case fire
}

private enum SevereRiskKind: String, Sendable {
    case allClear
    case wind
    case hail
    case tornado
}

private struct SevereRiskSignature: Sendable, Equatable {
    let kind: SevereRiskKind
    let probabilityPercent: Int?

    var fingerprintComponent: String {
        switch kind {
        case .allClear:
            return kind.rawValue
        case .wind, .hail, .tornado:
            return "\(kind.rawValue):\(probabilityPercent ?? 0)"
        }
    }
}

struct RiskProfile: Sendable, Equatable {
    let stormRisk: StormRiskLevel
    let severeRisk: SevereWeatherThreat
    let fireRisk: FireRiskLevel

    init(
        stormRisk: StormRiskLevel,
        severeRisk: SevereWeatherThreat,
        fireRisk: FireRiskLevel
    ) {
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
    }

    init?(stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?) {
        guard let stormRisk, let severeRisk, let fireRisk else {
            return nil
        }

        self.init(stormRisk: stormRisk, severeRisk: severeRisk, fireRisk: fireRisk)
    }

    static func == (lhs: RiskProfile, rhs: RiskProfile) -> Bool {
        lhs.stormRisk == rhs.stormRisk
            && lhs.severeSignature == rhs.severeSignature
            && lhs.fireRisk == rhs.fireRisk
    }

    var fingerprint: String {
        [
            "storm=\(stormRisk.rawValue)",
            "severe=\(severeSignature.fingerprintComponent)",
            "fire=\(fireRisk.rawValue)"
        ].joined(separator: "|")
    }

    func changedDimensions(from previous: RiskProfile) -> [RiskProfileDimension] {
        var dimensions: [RiskProfileDimension] = []

        if previous.stormRisk != stormRisk {
            dimensions.append(.storm)
        }
        if previous.severeSignature != severeSignature {
            dimensions.append(.severe)
        }
        if previous.fireRisk != fireRisk {
            dimensions.append(.fire)
        }

        return dimensions
    }

    private var severeSignature: SevereRiskSignature {
        switch severeRisk {
        case .allClear:
            return SevereRiskSignature(kind: .allClear, probabilityPercent: nil)
        case .wind(let probability):
            return SevereRiskSignature(kind: .wind, probabilityPercent: Self.normalizedProbabilityPercent(probability))
        case .hail(let probability):
            return SevereRiskSignature(kind: .hail, probabilityPercent: Self.normalizedProbabilityPercent(probability))
        case .tornado(let probability):
            return SevereRiskSignature(kind: .tornado, probabilityPercent: Self.normalizedProbabilityPercent(probability))
        }
    }

    private static func normalizedProbabilityPercent(_ probability: Double) -> Int {
        guard probability.isFinite else {
            return 0
        }
        return Int((probability * 100).rounded(.toNearestOrAwayFromZero))
    }
}

struct RiskProfileChange: Sendable, Equatable {
    /// Identifies one accepted persistence transition, rather than its destination profile.
    let occurrenceID: String
    let projectionKey: String
    let locationSummary: String?
    let previous: RiskProfile
    let current: RiskProfile
    let changedDimensions: [RiskProfileDimension]
    let previousFingerprint: String
    let currentFingerprint: String

    init?(
        previous: RiskProfile?,
        current: RiskProfile?,
        projectionKey: String,
        locationSummary: String?,
        occurrenceID: String = UUID().uuidString
    ) {
        guard let previous, let current else {
            return nil
        }

        let changedDimensions = current.changedDimensions(from: previous)
        guard changedDimensions.isEmpty == false else {
            return nil
        }

        self.occurrenceID = occurrenceID
        self.projectionKey = projectionKey
        self.locationSummary = locationSummary
        self.previous = previous
        self.current = current
        self.changedDimensions = changedDimensions
        self.previousFingerprint = previous.fingerprint
        self.currentFingerprint = current.fingerprint
    }
}

struct HomeProjectionCoreCommit: Sendable {
    let weather: SummaryWeather??
    let slowProducts: (stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?)?
    let hotAlerts: (alerts: [AlertDTO], mesos: [MdDTO])?

    init(
        weather: SummaryWeather?? = nil,
        slowProducts: (stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?)? = nil,
        hotAlerts: (alerts: [AlertDTO], mesos: [MdDTO])? = nil
    ) {
        self.weather = weather
        self.slowProducts = slowProducts
        self.hotAlerts = hotAlerts
    }
}

protocol HomeProjectionPersisting: Sendable {
    func projection(for context: LocationContext) async throws -> HomeProjectionRecord?

    func updateStormSetup(
        _ stormSetup: StormSetupCurrentResponse,
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> HomeProjectionRecord

    func updateWeather(
        _ weather: SummaryWeather?,
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> HomeProjectionRecord

    func updateSlowProducts(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?,
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> RiskProfileChange?

    func updateHotAlerts(
        alerts: [AlertDTO],
        mesos: [MdDTO],
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> HomeProjectionRecord

    func commitCore(
        _ commit: HomeProjectionCoreCommit,
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> RiskProfileChange?
}

extension HomeProjectionPersisting {
    func commitCore(
        _ commit: HomeProjectionCoreCommit,
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> RiskProfileChange? {
        var riskProfileChange: RiskProfileChange?
        if let weather = commit.weather {
            _ = try await updateWeather(weather, for: context, loadedAt: loadedAt)
        }
        if let slowProducts = commit.slowProducts {
            riskProfileChange = try await updateSlowProducts(
                stormRisk: slowProducts.stormRisk,
                severeRisk: slowProducts.severeRisk,
                fireRisk: slowProducts.fireRisk,
                for: context,
                loadedAt: loadedAt
            )
        }
        if let hotAlerts = commit.hotAlerts {
            _ = try await updateHotAlerts(
                alerts: hotAlerts.alerts,
                mesos: hotAlerts.mesos,
                for: context,
                loadedAt: loadedAt
            )
        }
        return riskProfileChange
    }
}

@ModelActor
actor HomeProjectionStore {
    private let performanceSignposter = OSSignposter(logger: Logger.appHomeRefresh)

    func projection(for context: LocationContext) throws -> HomeProjectionRecord? {
        try fetchProjection(withKey: HomeProjection.projectionKey(for: context))?.record
    }

    func latestProjectionForWidgetSnapshotRefresh() throws -> HomeProjectionRecord? {
        try fetchLatestProjection()?.record
    }

    func fetchOrCreateProjection(
        for context: LocationContext,
        viewedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(
            for: context,
            touchedAt: viewedAt,
            viewedAt: viewedAt,
            persistsExplicitly: true
        )
        return projection.record
    }

    func updateWeather(
        _ weather: SummaryWeather?,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.weatherPayload = weather.map(HomeProjectionWeatherPayload.init(summary:))
        projection.lastWeatherLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try saveProjection(named: "Projection Weather Save")
        return projection.record
    }

    func updateStormSetup(
        _ stormSetup: StormSetupCurrentResponse,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let payload = try StormSetupCurrentResponsePersistenceCodec.encode(stormSetup)
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.stormSetupCurrentResponseData = payload
        projection.lastStormSetupLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try saveProjection(named: "Projection Storm Setup Save")
        return projection.record
    }

    func updateSlowProducts(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> RiskProfileChange? {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        let previousProfile = RiskProfile(
            stormRisk: projection.stormRisk,
            severeRisk: projection.severeRisk,
            fireRisk: projection.fireRisk
        )
        let currentProfile = RiskProfile(
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk
        )
        let change = RiskProfileChange(
            previous: previousProfile,
            current: currentProfile,
            projectionKey: projection.projectionKey,
            locationSummary: projection.placemarkSummary
        )

        projection.stormRisk = stormRisk
        projection.severeRisk = severeRisk
        projection.fireRisk = fireRisk
        projection.lastSlowProductsLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try saveProjection(named: "Projection Slow Products Save")
        return change
    }

    func updateHotAlerts(
        alerts: [AlertDTO],
        mesos: [MdDTO],
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.activeAlerts = alerts
        projection.activeMesos = mesos
        projection.lastHotAlertsLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try saveProjection(named: "Projection Hot Alerts Save")
        return projection.record
    }

    func commitCore(
        _ commit: HomeProjectionCoreCommit,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> RiskProfileChange? {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        let previousProfile = RiskProfile(
            stormRisk: projection.stormRisk,
            severeRisk: projection.severeRisk,
            fireRisk: projection.fireRisk
        )

        if let weather = commit.weather {
            projection.weatherPayload = weather.map(HomeProjectionWeatherPayload.init(summary:))
            projection.lastWeatherLoadAt = loadedAt
        }
        if let slowProducts = commit.slowProducts {
            projection.stormRisk = slowProducts.stormRisk
            projection.severeRisk = slowProducts.severeRisk
            projection.fireRisk = slowProducts.fireRisk
            projection.lastSlowProductsLoadAt = loadedAt
        }
        if let hotAlerts = commit.hotAlerts {
            projection.activeAlerts = hotAlerts.alerts
            projection.activeMesos = hotAlerts.mesos
            projection.lastHotAlertsLoadAt = loadedAt
        }

        projection.updatedAt = loadedAt
        try saveProjection(named: "Projection Core Save")
        return RiskProfileChange(
            previous: previousProfile,
            current: commit.slowProducts.flatMap {
                RiskProfile(
                    stormRisk: $0.stormRisk,
                    severeRisk: $0.severeRisk,
                    fireRisk: $0.fireRisk
                )
            },
            projectionKey: projection.projectionKey,
            locationSummary: projection.placemarkSummary
        )
    }

    private func fetchOrCreateModel(
        for context: LocationContext,
        touchedAt: Date,
        viewedAt: Date? = nil,
        persistsExplicitly: Bool = false
    ) throws -> HomeProjection {
        if let existing = try fetchProjection(withKey: HomeProjection.projectionKey(for: context)) {
            existing.updateLocationContext(context, touchedAt: touchedAt, viewedAt: viewedAt)
            if persistsExplicitly {
                try saveProjection(named: "Projection Touch Save")
            }
            return existing
        }

        let projection = HomeProjection(context: context, createdAt: touchedAt, lastViewedAt: viewedAt)
        modelContext.insert(projection)
        if persistsExplicitly {
            try saveProjection(named: "Projection Create Save")
        }
        return projection
    }

    private func saveProjection(named name: StaticString) throws {
        let interval = performanceSignposter.beginInterval(name)
        defer { performanceSignposter.endInterval(name, interval) }
        try modelContext.save()
    }

    private func fetchProjection(withKey projectionKey: String) throws -> HomeProjection? {
        let predicate = #Predicate<HomeProjection> { projection in
            projection.projectionKey == projectionKey
        }
        var descriptor = FetchDescriptor<HomeProjection>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchLatestProjection() throws -> HomeProjection? {
        var descriptor = FetchDescriptor<HomeProjection>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.projectionKey, order: .forward)
            ]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

extension HomeProjectionStore: HomeProjectionPersisting {}
