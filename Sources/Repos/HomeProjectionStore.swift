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
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?

    init(
        stormRisk: StormRiskLevel,
        severeRisk: SevereWeatherThreat,
        fireRisk: FireRiskLevel
    ) {
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
    }

    init(stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?) {
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
    }

    static func == (lhs: RiskProfile, rhs: RiskProfile) -> Bool {
        lhs.stormRisk == rhs.stormRisk
            && lhs.severeSignature == rhs.severeSignature
            && lhs.fireRisk == rhs.fireRisk
    }

    var fingerprint: String {
        [
            "storm=\(stormRisk.map { String($0.rawValue) } ?? "unavailable")",
            "severe=\(severeSignature?.fingerprintComponent ?? "unavailable")",
            "fire=\(fireRisk.map { String($0.rawValue) } ?? "unavailable")"
        ].joined(separator: "|")
    }

    func changedDimensions(from previous: RiskProfile) -> [RiskProfileDimension] {
        var dimensions: [RiskProfileDimension] = []

        if let previousStorm = previous.stormRisk, let stormRisk, previousStorm != stormRisk {
            dimensions.append(.storm)
        }
        if let previousSevere = previous.severeSignature,
           let severeSignature,
           previousSevere != severeSignature {
            dimensions.append(.severe)
        }
        if let previousFire = previous.fireRisk, let fireRisk, previousFire != fireRisk {
            dimensions.append(.fire)
        }

        return dimensions
    }

    private var severeSignature: SevereRiskSignature? {
        guard let severeRisk else { return nil }
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
    let comparisonLocationKey: String?
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
        comparisonLocationKey: String? = nil,
        locationSummary: String?,
        eligibleDimensions: [RiskProfileDimension]? = nil,
        occurrenceID: String = UUID().uuidString
    ) {
        guard let previous, let current else {
            return nil
        }

        let detectedDimensions = current.changedDimensions(from: previous)
        let changedDimensions = eligibleDimensions.map { eligible in
            detectedDimensions.filter(eligible.contains)
        } ?? detectedDimensions
        guard changedDimensions.isEmpty == false else {
            return nil
        }

        self.occurrenceID = occurrenceID
        self.projectionKey = projectionKey
        self.comparisonLocationKey = comparisonLocationKey
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
    let updatesConvectiveRisk: Bool
    let updatesFireRisk: Bool
    let convectiveSource: SpcMapSourceIdentity?
    let fireSource: SpcMapSourceIdentity?
    let hotAlerts: (alerts: [AlertDTO], mesos: [MdDTO])?

    init(
        weather: SummaryWeather?? = nil,
        slowProducts: (stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?)? = nil,
        updatesConvectiveRisk: Bool = true,
        updatesFireRisk: Bool = true,
        convectiveSource: SpcMapSourceIdentity? = nil,
        fireSource: SpcMapSourceIdentity? = nil,
        hotAlerts: (alerts: [AlertDTO], mesos: [MdDTO])? = nil
    ) {
        self.weather = weather
        self.slowProducts = slowProducts
        self.updatesConvectiveRisk = updatesConvectiveRisk
        self.updatesFireRisk = updatesFireRisk
        self.convectiveSource = convectiveSource
        self.fireSource = fireSource
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
        convectiveSource: SpcMapSourceIdentity?,
        fireSource: SpcMapSourceIdentity?,
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
    func updateSlowProducts(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?,
        for context: LocationContext,
        loadedAt: Date
    ) async throws -> RiskProfileChange? {
        try await updateSlowProducts(
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            convectiveSource: nil,
            fireSource: nil,
            for: context,
            loadedAt: loadedAt
        )
    }
}

@ModelActor
actor HomeProjectionStore {
    private let performanceSignposter = OSSignposter(logger: Logger.appHomeRefresh)
#if DEBUG
    private var failsNextSaveForTesting = false

    func failNextSaveForTesting() {
        failsNextSaveForTesting = true
    }
#endif

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
        convectiveSource: SpcMapSourceIdentity? = nil,
        fireSource: SpcMapSourceIdentity? = nil,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> RiskProfileChange? {
        try commitCore(
            .init(
                slowProducts: (stormRisk, severeRisk, fireRisk),
                convectiveSource: convectiveSource,
                fireSource: fireSource
            ),
            for: context,
            loadedAt: loadedAt
        )
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
        var eligibleDimensions: [RiskProfileDimension] = []

        if let weather = commit.weather {
            projection.weatherPayload = weather.map(HomeProjectionWeatherPayload.init(summary:))
            projection.lastWeatherLoadAt = loadedAt
        }
        if let slowProducts = commit.slowProducts {
            if commit.updatesConvectiveRisk {
                if try advancesComparisonBaseline(
                    for: .convective,
                    projection: projection,
                    context: context,
                    acceptedSource: commit.convectiveSource
                ) {
                    eligibleDimensions.append(contentsOf: [.storm, .severe])
                }
                projection.stormRisk = slowProducts.stormRisk
                projection.severeRisk = slowProducts.severeRisk
            }
            if commit.updatesFireRisk {
                if try advancesComparisonBaseline(
                    for: .fire,
                    projection: projection,
                    context: context,
                    acceptedSource: commit.fireSource
                ) {
                    eligibleDimensions.append(.fire)
                }
                projection.fireRisk = slowProducts.fireRisk
            }
            if commit.updatesConvectiveRisk && commit.updatesFireRisk {
                projection.lastSlowProductsLoadAt = loadedAt
            }
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
            current: commit.slowProducts.flatMap { _ in
                RiskProfile(
                    stormRisk: projection.stormRisk,
                    severeRisk: projection.severeRisk,
                    fireRisk: projection.fireRisk
                )
            },
            projectionKey: projection.projectionKey,
            comparisonLocationKey: HomeProjection.riskComparisonLocationKey(for: context),
            locationSummary: projection.placemarkSummary,
            eligibleDimensions: eligibleDimensions
        )
    }

    private enum RiskComparisonDomain {
        case convective
        case fire
    }

    /// A domain can notify only when a newly accepted SPC source replaces the source sampled at the same
    /// projection-plus-E4 location identity. All other writes rebase the active domain baseline silently.
    private func advancesComparisonBaseline(
        for domain: RiskComparisonDomain,
        projection: HomeProjection,
        context: LocationContext,
        acceptedSource: SpcMapSourceIdentity?
    ) throws -> Bool {
        let locationKey = HomeProjection.riskComparisonLocationKey(for: context)
        let previousLocationKey = comparisonLocationKey(for: domain, projection: projection)
        let previousSourceKey = comparisonSourceKey(for: domain, projection: projection)
        let acceptedSourceKey = acceptedSource?.persistenceToken
        let inheritedSourceKey = try previousSourceKey ?? activeComparisonSourceKey(for: domain)
        let advances = previousLocationKey == locationKey
            && previousSourceKey != nil
            && acceptedSourceKey != nil
            && acceptedSourceKey != previousSourceKey

        try invalidateOtherComparisonBaselines(for: domain, keeping: projection)
        setComparisonBaseline(
            for: domain,
            projection: projection,
            locationKey: locationKey,
            sourceKey: acceptedSourceKey ?? inheritedSourceKey
        )
        return advances
    }

    private func activeComparisonSourceKey(for domain: RiskComparisonDomain) throws -> String? {
        let descriptor = FetchDescriptor<HomeProjection>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.projectionKey, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor).lazy.compactMap {
            self.comparisonSourceKey(for: domain, projection: $0)
        }.first
    }

    private func invalidateOtherComparisonBaselines(
        for domain: RiskComparisonDomain,
        keeping projection: HomeProjection
    ) throws {
        for other in try modelContext.fetch(FetchDescriptor<HomeProjection>()) where other.id != projection.id {
            setComparisonBaseline(for: domain, projection: other, locationKey: nil, sourceKey: nil)
        }
    }

    private func comparisonLocationKey(
        for domain: RiskComparisonDomain,
        projection: HomeProjection
    ) -> String? {
        switch domain {
        case .convective: projection.convectiveRiskComparisonLocationKey
        case .fire: projection.fireRiskComparisonLocationKey
        }
    }

    private func comparisonSourceKey(for domain: RiskComparisonDomain, projection: HomeProjection) -> String? {
        switch domain {
        case .convective: projection.convectiveRiskComparisonSourceKey
        case .fire: projection.fireRiskComparisonSourceKey
        }
    }

    private func setComparisonBaseline(
        for domain: RiskComparisonDomain,
        projection: HomeProjection,
        locationKey: String?,
        sourceKey: String?
    ) {
        switch domain {
        case .convective:
            projection.convectiveRiskComparisonLocationKey = locationKey
            projection.convectiveRiskComparisonSourceKey = sourceKey
        case .fire:
            projection.fireRiskComparisonLocationKey = locationKey
            projection.fireRiskComparisonSourceKey = sourceKey
        }
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
        do {
#if DEBUG
            if failsNextSaveForTesting {
                failsNextSaveForTesting = false
                throw HomeProjectionStoreTestingError.injectedSaveFailure
            }
#endif
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
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

#if DEBUG
private enum HomeProjectionStoreTestingError: Error {
    case injectedSaveFailure
}
#endif

extension HomeProjectionStore: HomeProjectionPersisting {}
