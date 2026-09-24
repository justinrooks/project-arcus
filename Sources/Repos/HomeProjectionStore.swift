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

struct RiskProfile: Sendable, Codable, Equatable {
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

/// Versioned payload stored in the existing comparison-source columns. The baseline fields are consumed only by
/// background ingestion; `observedSourceKey` may advance in the foreground so presentation can remain current.
struct RiskComparisonBaselineState: Sendable, Codable, Equatable {
    private static let prefix = "risk-baseline-v1:"

    let baselineSourceKey: String?
    let observedSourceKey: String?
    let profile: RiskProfile?

    var persistenceToken: String? {
        guard baselineSourceKey != nil || observedSourceKey != nil || profile != nil,
              let data = try? JSONEncoder().encode(self) else {
            return nil
        }
        return Self.prefix + data.base64EncodedString()
    }

    static func decode(_ token: String?, legacyProfile: RiskProfile? = nil) -> Self? {
        guard let token else { return nil }
        guard token.hasPrefix(prefix) else {
            return .init(
                baselineSourceKey: token,
                observedSourceKey: token,
                profile: legacyProfile
            )
        }
        guard let data = Data(base64Encoded: String(token.dropFirst(prefix.count))) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func observedSourceKey(from token: String?) -> String? {
        decode(token)?.observedSourceKey
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

struct HomeProjectionCommitAcknowledgement: Sendable, Equatable {
    let record: HomeProjectionRecord
    let riskProfileChange: RiskProfileChange?
}

struct HomeProjectionCoreCommit: Sendable {
    enum RiskComparisonMode: Sendable, Equatable {
        case evaluate
        case observeOnly
    }

    let weather: SummaryWeather??
    let slowProducts: (stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?)?
    let updatesConvectiveRisk: Bool
    let updatesFireRisk: Bool
    let convectiveSource: SpcMapSourceIdentity?
    let fireSource: SpcMapSourceIdentity?
    let riskComparisonMode: RiskComparisonMode
    let hotAlerts: (alerts: [AlertDTO], mesos: [MdDTO])?

    init(
        weather: SummaryWeather?? = nil,
        slowProducts: (stormRisk: StormRiskLevel?, severeRisk: SevereWeatherThreat?, fireRisk: FireRiskLevel?)? = nil,
        updatesConvectiveRisk: Bool = true,
        updatesFireRisk: Bool = true,
        convectiveSource: SpcMapSourceIdentity? = nil,
        fireSource: SpcMapSourceIdentity? = nil,
        riskComparisonMode: RiskComparisonMode = .evaluate,
        hotAlerts: (alerts: [AlertDTO], mesos: [MdDTO])? = nil
    ) {
        self.weather = weather
        self.slowProducts = slowProducts
        self.updatesConvectiveRisk = updatesConvectiveRisk
        self.updatesFireRisk = updatesFireRisk
        self.convectiveSource = convectiveSource
        self.fireSource = fireSource
        self.riskComparisonMode = riskComparisonMode
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

    func updateAirQuality(
        _ airQuality: AirQualityCurrentResponse,
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
    ) async throws -> HomeProjectionCommitAcknowledgement
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
    static let recentRetentionAge: TimeInterval = 30 * 24 * 60 * 60
    static let maximumRecentUsefulProjections = 10
    private static let pendingRetentionIDsDefaultsKey = "homeProjection.pendingRetentionIDs.v1"

    private let performanceSignposter = OSSignposter(logger: Logger.appHomeRefresh)

    private var retentionCoordinator: HomeProjectionRetentionCoordinator {
        HomeProjectionRetentionCoordinator.forStore(modelContainer)
    }

    private var scopedPendingRetentionIDsDefaultsKey: String {
        let storePath = modelContainer.configurations.first?.url.standardizedFileURL.path ?? "default"
        let pathHash = storePath.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return "\(Self.pendingRetentionIDsDefaultsKey).\(String(pathHash, radix: 16))"
    }

#if DEBUG
    private var failsNextSaveForTesting = false
    private var operationMetrics = HomeProjectionStoreOperationMetrics()
    private var retentionCheckpointForTesting: (@Sendable () async -> Void)?

    func failNextSaveForTesting() {
        failsNextSaveForTesting = true
    }

    func resetOperationMetricsForTesting() {
        operationMetrics = HomeProjectionStoreOperationMetrics()
    }

    func operationMetricsForTesting() -> HomeProjectionStoreOperationMetrics {
        operationMetrics
    }

    func setRetentionCheckpointForTesting(_ checkpoint: (@Sendable () async -> Void)?) {
        retentionCheckpointForTesting = checkpoint
    }
#endif

    func projection(for context: LocationContext) throws -> HomeProjectionRecord? {
        try fetchProjection(withKey: HomeProjection.projectionKey(for: context))?.record
    }

    func latestProjectionForWidgetSnapshotRefresh() throws -> HomeProjectionRecord? {
        try fetchLatestProjection()?.record
    }

    func newestDisplayReadyProjection() throws -> HomeProjectionRecord? {
        let projections = try modelContext.fetch(HomeProjection.orderedProjectionsDescriptor())
        recordFetchedRows(projections.count)
        return HomeProjectionRecord.newestDisplayReady(in: projections.map(\.record))
    }

    func retainRecentProjections(
        forActiveContext activeContext: LocationContext,
        now: Date = .now
    ) async throws {
#if DEBUG
        await retentionCheckpointForTesting?()
#endif
        try Task.checkCancellation()

        let coordinator = retentionCoordinator
        await coordinator.acquire()
        defer { coordinator.release() }
        try Task.checkCancellation()

        let projections = try modelContext.fetch(HomeProjection.orderedProjectionsDescriptor())
        recordFetchedRows(projections.count)

        let cutoff = now.addingTimeInterval(-Self.recentRetentionAge)
        let activeProjectionKey = HomeProjection.projectionKey(for: activeContext)
        let activeProjection = projections.first { $0.projectionKey == activeProjectionKey }
        let startupFallback = HomeProjectionRecord.newestDisplayReady(in: projections.map(\.record))?.id
        let recentUseful = projections
            .filter { projection in
                projection.record.isDisplayReady
                    && max(projection.updatedAt, projection.lastViewedAt ?? .distantPast) >= cutoff
            }
            .sorted(by: Self.isMoreRecentlyUseful)
            .prefix(Self.maximumRecentUsefulProjections)

        var retainedIDs = Set(recentUseful.map(\.id))
        if let startupFallback {
            retainedIDs.insert(startupFallback)
        }
        if let activeProjection {
            retainedIDs.insert(activeProjection.id)
        }

        var protectedIDs = retainedIDs
        let currentActiveKey = coordinator.currentActiveProjectionKey()
        let currentActiveProjection = projections.first { $0.projectionKey == currentActiveKey }
        if let currentActiveProjection {
            protectedIDs.insert(currentActiveProjection.id)
        }

        let currentCandidateIDs = Set(
            projections.lazy.map(\.id).filter { protectedIDs.contains($0) == false }
        )
        let pendingIDs = Set(
            UserDefaults.standard.stringArray(forKey: scopedPendingRetentionIDsDefaultsKey) ?? []
        )
        let removed = projections.filter {
            currentCandidateIDs.contains($0.id) && pendingIDs.contains($0.id.uuidString)
        }

        let didRecordPassedContext = activeProjection.map { $0.lastViewedAt != now } ?? false
        activeProjection?.lastViewedAt = now
        let didRecordCurrentContext = currentActiveProjection.map { $0.lastViewedAt != now } ?? false
        currentActiveProjection?.lastViewedAt = now

        for projection in removed {
            modelContext.delete(projection)
        }
        if Task.isCancelled {
            modelContext.rollback()
            throw CancellationError()
        }
        if removed.isEmpty == false || didRecordPassedContext || didRecordCurrentContext {
            try saveProjection(named: "Home Projection Retention Save")
        }

        // Stage candidates even when the active context has no row yet. A later sweep
        // deletes only rows that remain outside the active, fallback, and recent sets.
        let nextPendingIDs = currentCandidateIDs.subtracting(removed.map(\.id))
        UserDefaults.standard.set(
            nextPendingIDs.map(\.uuidString).sorted(),
            forKey: scopedPendingRetentionIDsDefaultsKey
        )
    }

    private static func isMoreRecentlyUseful(_ lhs: HomeProjection, _ rhs: HomeProjection) -> Bool {
        let lhsUsefulAt = max(lhs.updatedAt, lhs.lastViewedAt ?? .distantPast)
        let rhsUsefulAt = max(rhs.updatedAt, rhs.lastViewedAt ?? .distantPast)
        if lhsUsefulAt != rhsUsefulAt { return lhsUsefulAt > rhsUsefulAt }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.projectionKey < rhs.projectionKey
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

    func updateAirQuality(
        _ airQuality: AirQualityCurrentResponse,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projectionKey = HomeProjection.projectionKey(for: context)
        if let existing = try fetchProjection(withKey: projectionKey),
           let observedAt = existing.airQualityObservedAt,
           airQuality.observedAt < observedAt {
            return existing.record
        }

        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.setAirQuality(airQuality)
        projection.lastAirQualityLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try saveProjection(named: "Projection Air Quality Save")
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
        ).riskProfileChange
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
    ) throws -> HomeProjectionCommitAcknowledgement {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        let persistedProfile = RiskProfile(
            stormRisk: projection.stormRisk,
            severeRisk: projection.severeRisk,
            fireRisk: projection.fireRisk
        )
        var eligibleDimensions: [RiskProfileDimension] = []
        var previousStormRisk: StormRiskLevel?
        var previousSevereRisk: SevereWeatherThreat?
        var previousFireRisk: FireRiskLevel?

        if let weather = commit.weather {
            projection.weatherPayload = weather.map(HomeProjectionWeatherPayload.init(summary:))
            projection.lastWeatherLoadAt = loadedAt
        }
        if let slowProducts = commit.slowProducts {
            if commit.updatesConvectiveRisk {
                projection.stormRisk = slowProducts.stormRisk
                projection.severeRisk = slowProducts.severeRisk
            }
            if commit.updatesFireRisk {
                projection.fireRisk = slowProducts.fireRisk
            }
            let currentProfile = RiskProfile(
                stormRisk: projection.stormRisk,
                severeRisk: projection.severeRisk,
                fireRisk: projection.fireRisk
            )
            previousStormRisk = currentProfile.stormRisk
            previousSevereRisk = currentProfile.severeRisk
            previousFireRisk = currentProfile.fireRisk

            if commit.updatesConvectiveRisk,
               let previousProfile = try processComparisonBaseline(
                   for: .convective,
                   projection: projection,
                   context: context,
                   acceptedSource: commit.convectiveSource,
                   currentProfile: currentProfile,
                   persistedProfile: persistedProfile,
                   mode: commit.riskComparisonMode
               ) {
                previousStormRisk = previousProfile.stormRisk
                previousSevereRisk = previousProfile.severeRisk
                eligibleDimensions.append(contentsOf: [.storm, .severe])
            }
            if commit.updatesFireRisk,
               let previousProfile = try processComparisonBaseline(
                   for: .fire,
                   projection: projection,
                   context: context,
                   acceptedSource: commit.fireSource,
                   currentProfile: currentProfile,
                   persistedProfile: persistedProfile,
                   mode: commit.riskComparisonMode
               ) {
                previousFireRisk = previousProfile.fireRisk
                eligibleDimensions.append(.fire)
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
        return .init(
            record: projection.record,
            riskProfileChange: .init(
                previous: commit.slowProducts.map { _ in
                    RiskProfile(
                        stormRisk: previousStormRisk,
                        severeRisk: previousSevereRisk,
                        fireRisk: previousFireRisk
                    )
                },
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
        )
    }

    private enum RiskComparisonDomain {
        case convective
        case fire
    }

    /// Returns the prior background-consumed profile only for a forecast transition at the same H3 cell or a
    /// location transition under the same accepted source. Foreground writes update observed source metadata but
    /// never consume the notification baseline.
    private func processComparisonBaseline(
        for domain: RiskComparisonDomain,
        projection: HomeProjection,
        context: LocationContext,
        acceptedSource: SpcMapSourceIdentity?,
        currentProfile: RiskProfile,
        persistedProfile: RiskProfile,
        mode: HomeProjectionCoreCommit.RiskComparisonMode
    ) throws -> RiskProfile? {
        let locationKey = HomeProjection.riskComparisonLocationKey(for: context)
        let acceptedSourceKey = acceptedSource?.persistenceToken
        let comparisonProjections = try fetchComparisonProjections(for: domain)
        let activeBaseline = activeComparisonBaseline(
            for: domain,
            in: comparisonProjections,
            currentProjection: projection,
            persistedProfile: persistedProfile
        )
        let localState = comparisonState(
            for: domain,
            projection: projection,
            legacyProfile: persistedProfile
        )
        let observedSourceKey = acceptedSourceKey
            ?? localState?.observedSourceKey
            ?? activeBaseline?.state.observedSourceKey
            ?? activeBaseline?.state.baselineSourceKey

        if mode == .observeOnly {
            let state: RiskComparisonBaselineState
            if comparisonLocationKey(for: domain, projection: projection) != nil,
               let localState {
                state = .init(
                    baselineSourceKey: localState.baselineSourceKey,
                    observedSourceKey: observedSourceKey,
                    profile: localState.profile
                )
            } else {
                state = .init(
                    baselineSourceKey: nil,
                    observedSourceKey: observedSourceKey,
                    profile: nil
                )
            }
            setComparisonState(
                for: domain,
                projection: projection,
                locationKey: comparisonLocationKey(for: domain, projection: projection),
                state: state
            )
            return nil
        }

        let isForecastTransition = activeBaseline?.locationKey == locationKey
            && activeBaseline?.state.baselineSourceKey != nil
            && observedSourceKey != nil
            && observedSourceKey != activeBaseline?.state.baselineSourceKey
        let isLocationTransition = activeBaseline?.locationKey != locationKey
            && activeBaseline?.state.baselineSourceKey != nil
            && observedSourceKey == activeBaseline?.state.baselineSourceKey
        let previousProfile = isForecastTransition || isLocationTransition
            ? activeBaseline?.state.profile
            : nil

        invalidateOtherComparisonBaselines(
            for: domain,
            in: comparisonProjections,
            keeping: projection
        )
        setComparisonState(
            for: domain,
            projection: projection,
            locationKey: locationKey,
            state: .init(
                baselineSourceKey: observedSourceKey,
                observedSourceKey: observedSourceKey,
                profile: domainProfile(for: domain, from: currentProfile)
            )
        )
        return previousProfile
    }

    private func activeComparisonBaseline(
        for domain: RiskComparisonDomain,
        in projections: [HomeProjection],
        currentProjection: HomeProjection,
        persistedProfile: RiskProfile
    ) -> (locationKey: String, state: RiskComparisonBaselineState)? {
        projections.lazy.compactMap { projection in
            guard let storedLocationKey = self.comparisonLocationKey(for: domain, projection: projection),
                  let state = self.comparisonState(
                      for: domain,
                      projection: projection,
                      legacyProfile: projection.id == currentProjection.id ? persistedProfile : nil
                  ),
                  state.baselineSourceKey != nil,
                  state.profile != nil else {
                return nil
            }
            return (self.normalizedComparisonLocationKey(storedLocationKey, projection: projection), state)
        }.first
    }

    private func fetchComparisonProjections(for domain: RiskComparisonDomain) throws -> [HomeProjection] {
        let descriptor: FetchDescriptor<HomeProjection>
        switch domain {
        case .convective:
            descriptor = FetchDescriptor(
                predicate: #Predicate {
                    $0.convectiveRiskComparisonLocationKey != nil || $0.convectiveRiskComparisonSourceKey != nil
                },
                sortBy: [
                    SortDescriptor(\.updatedAt, order: .reverse),
                    SortDescriptor(\.projectionKey, order: .forward)
                ]
            )
        case .fire:
            descriptor = FetchDescriptor(
                predicate: #Predicate {
                    $0.fireRiskComparisonLocationKey != nil || $0.fireRiskComparisonSourceKey != nil
                },
                sortBy: [
                    SortDescriptor(\.updatedAt, order: .reverse),
                    SortDescriptor(\.projectionKey, order: .forward)
                ]
            )
        }
        let projections = try modelContext.fetch(descriptor)
        recordFetchedRows(projections.count)
        return projections
    }

    private func invalidateOtherComparisonBaselines(
        for domain: RiskComparisonDomain,
        in projections: [HomeProjection],
        keeping projection: HomeProjection
    ) {
        for other in projections where other.id != projection.id {
            setComparisonState(for: domain, projection: other, locationKey: nil, state: nil)
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

    private func comparisonState(
        for domain: RiskComparisonDomain,
        projection: HomeProjection,
        legacyProfile: RiskProfile? = nil
    ) -> RiskComparisonBaselineState? {
        let token: String?
        switch domain {
        case .convective: token = projection.convectiveRiskComparisonSourceKey
        case .fire: token = projection.fireRiskComparisonSourceKey
        }
        return RiskComparisonBaselineState.decode(
            token,
            legacyProfile: domainProfile(
                for: domain,
                from: legacyProfile ?? RiskProfile(
                    stormRisk: projection.stormRisk,
                    severeRisk: projection.severeRisk,
                    fireRisk: projection.fireRisk
                )
            )
        )
    }

    private func normalizedComparisonLocationKey(
        _ storedLocationKey: String,
        projection: HomeProjection
    ) -> String {
        guard storedLocationKey.hasPrefix("h3-r8:") == false else { return storedLocationKey }
        return "h3-r8:\(projection.h3Cell)"
    }

    private func domainProfile(for domain: RiskComparisonDomain, from profile: RiskProfile) -> RiskProfile {
        switch domain {
        case .convective:
            RiskProfile(stormRisk: profile.stormRisk, severeRisk: profile.severeRisk, fireRisk: nil)
        case .fire:
            RiskProfile(stormRisk: nil, severeRisk: nil, fireRisk: profile.fireRisk)
        }
    }

    private func setComparisonState(
        for domain: RiskComparisonDomain,
        projection: HomeProjection,
        locationKey: String?,
        state: RiskComparisonBaselineState?
    ) {
        let sourceKey = state?.persistenceToken
        let didChange: Bool
        switch domain {
        case .convective:
            didChange = projection.convectiveRiskComparisonLocationKey != locationKey
                || projection.convectiveRiskComparisonSourceKey != sourceKey
            projection.convectiveRiskComparisonLocationKey = locationKey
            projection.convectiveRiskComparisonSourceKey = sourceKey
        case .fire:
            didChange = projection.fireRiskComparisonLocationKey != locationKey
                || projection.fireRiskComparisonSourceKey != sourceKey
            projection.fireRiskComparisonLocationKey = locationKey
            projection.fireRiskComparisonSourceKey = sourceKey
        }
        recordComparisonBaselineWrite(didChange: didChange)
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
            recordSave()
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
        let projections = try modelContext.fetch(descriptor)
        recordFetchedRows(projections.count)
        return projections.first
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
        let projections = try modelContext.fetch(descriptor)
        recordFetchedRows(projections.count)
        return projections.first
    }

    private func recordFetchedRows(_ count: Int) {
#if DEBUG
        operationMetrics.fetchCount += 1
        operationMetrics.rowsFetched += count
#endif
    }

    private func recordComparisonBaselineWrite(didChange: Bool) {
#if DEBUG
        operationMetrics.comparisonBaselineWriteCount += 1
        if didChange {
            operationMetrics.comparisonBaselineChangedCount += 1
        }
#endif
    }

    private func recordSave() {
#if DEBUG
        operationMetrics.saveCount += 1
#endif
    }
}

#if DEBUG
struct HomeProjectionStoreOperationMetrics: Sendable, Equatable {
    var fetchCount = 0
    var rowsFetched = 0
    var comparisonBaselineWriteCount = 0
    var comparisonBaselineChangedCount = 0
    var saveCount = 0
}

private enum HomeProjectionStoreTestingError: Error {
    case injectedSaveFailure
}
#endif

extension HomeProjectionStore: HomeProjectionPersisting {}
