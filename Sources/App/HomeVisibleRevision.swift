import ArcusCore
import Foundation

/// A location-scoped, persisted Home picture. Core fields always come from one accepted projection.
/// Alerts and optional enrichment may advance independently without changing that core picture.
struct HomeVisibleRevision: Sendable, Equatable {
    let core: HomeProjectionRecord
    let alerts: HomeProjectionRecord?
    let enrichment: HomeProjectionRecord?

    var projectionKey: String { core.projectionKey }
    var weather: SummaryWeather? { core.weather }
    var stormRisk: StormRiskLevel? { core.stormRisk }
    var severeRisk: SevereWeatherThreat? { core.severeRisk }
    var fireRisk: FireRiskLevel? { core.fireRisk }
    var activeAlerts: [AlertDTO] { (alerts ?? core).activeAlerts }
    var activeMesos: [MdDTO] { (alerts ?? core).activeMesos }
    var airQuality: AirQualityCurrentResponse? { (enrichment ?? core).airQuality }
    var stormSetup: StormSetupDTO? { (enrichment ?? core).stormSetup }
    var stormSetupCurrentResponse: StormSetupCurrentResponse? {
        (enrichment ?? core).stormSetupCurrentResponse
    }

    /// Nil values are accepted empty only after each core domain and alerts have an acceptance marker.
    var isAuthoritativelyEmpty: Bool {
        core.lastWeatherLoadAt != nil && core.lastSlowProductsLoadAt != nil &&
        (alerts ?? core).lastHotAlertsLoadAt != nil &&
        weather == nil && stormRisk == nil && severeRisk == nil && fireRisk == nil &&
        activeAlerts.isEmpty && activeMesos.isEmpty
    }
}

/// Pure transition contract for #453. #458/#449 will wire repository observations and ingestion events to it.
struct HomeVisiblePresentation: Sendable, Equatable {
    enum RefreshSource: Sendable, Equatable, CaseIterable {
        case foregroundActivate
        case manual
        case timer
        case background
    }

    enum Phase: Sendable, Equatable {
        case current
        case cachedRefreshing
        case staleOffline
        case noCacheResolving
        case authoritativeEmpty
        case failureWithCache
        case noCacheFailure
        case locationUnavailable
        case persistenceUnavailable
    }

    enum Outcome: Sendable, Equatable {
        case none
        case failed
        case rejected
        case offline
    }

    enum Event: Sendable {
        case contextChanged(projectionKey: String?)
        case refreshStarted(id: UUID, source: RefreshSource, projectionKey: String?)
        case refreshFinished(id: UUID)
        /// Only a repository acknowledgement for a commit that accepted weather and/or slow products
        /// may promote core. A hot-alert-only prime is deliberately ineligible.
        case coreAccepted(HomeProjectionCommitAcknowledgement, HomeProjectionCoreCommit)
        case persistedFallback(HomeProjectionRecord)
        case alertsAccepted(HomeProjectionRecord)
        case enrichmentAccepted(HomeProjectionRecord)
        case failed(id: UUID)
        case rejected(id: UUID)
        case offline(id: UUID)
        case connectivityChanged(isOffline: Bool)
        case locationUnavailable
        case persistenceUnavailable(projectionKey: String?)
        case persistenceRecovered(projectionKey: String?)
    }

    private(set) var contextKey: String?
    private(set) var revision: HomeVisibleRevision?
    private(set) var isRefreshing = false
    private(set) var refreshSource: RefreshSource?
    private(set) var activeAttemptID: UUID?
    private(set) var outcome: Outcome = .none
    private(set) var isOffline = false
    private(set) var isLocationUnavailable = false
    private(set) var isPersistenceUnavailable = false

    init(contextKey: String? = nil) {
        self.contextKey = contextKey
    }

    var phase: Phase {
        if isLocationUnavailable { return .locationUnavailable }
        if isPersistenceUnavailable { return .persistenceUnavailable }
        guard let revision else {
            return outcome == .failed || outcome == .rejected ? .noCacheFailure : .noCacheResolving
        }
        if outcome == .failed || outcome == .rejected { return .failureWithCache }
        if outcome == .offline || isOffline { return .staleOffline }
        if isRefreshing { return .cachedRefreshing }
        return revision.isAuthoritativelyEmpty ? .authoritativeEmpty : .current
    }

    mutating func apply(_ event: Event) {
        switch event {
        case .contextChanged(let projectionKey):
            guard contextKey != projectionKey else { return }
            revision = nil
            contextKey = projectionKey
            isLocationUnavailable = false
            isRefreshing = false
            refreshSource = nil
            activeAttemptID = nil
            outcome = .none
            isPersistenceUnavailable = false
        case .refreshStarted(let id, let source, let projectionKey):
            guard contextKey == projectionKey else { return }
            isRefreshing = true
            refreshSource = source
            activeAttemptID = id
            outcome = .none
        case .refreshFinished(let id):
            guard activeAttemptID == id else { return }
            isRefreshing = false
            refreshSource = nil
            activeAttemptID = nil
        case .coreAccepted(let acknowledgement, let commit):
            guard commit.weather != nil || commit.slowProducts != nil else { return }
            acceptCore(acknowledgement.record)
        case .persistedFallback(let record):
            guard revision == nil,
                  record.lastWeatherLoadAt != nil || record.lastSlowProductsLoadAt != nil else { return }
            acceptCore(record)
        case .alertsAccepted(let record):
            guard record.projectionKey == contextKey, record.lastHotAlertsLoadAt != nil,
                  let current = revision, record.updatedAt >= (current.alerts ?? current.core).updatedAt else { return }
            revision = HomeVisibleRevision(core: current.core, alerts: record, enrichment: current.enrichment)
        case .enrichmentAccepted(let record):
            guard record.projectionKey == contextKey,
                  record.lastAirQualityLoadAt != nil || record.lastStormSetupLoadAt != nil,
                  let current = revision,
                  record.updatedAt >= (current.enrichment ?? current.core).updatedAt else { return }
            revision = HomeVisibleRevision(core: current.core, alerts: current.alerts, enrichment: record)
        case .failed(let id):
            guard activeAttemptID == id else { return }
            outcome = .failed
            isRefreshing = false
            refreshSource = nil
            activeAttemptID = nil
        case .rejected(let id):
            guard activeAttemptID == id else { return }
            outcome = .rejected
            isRefreshing = false
            refreshSource = nil
            activeAttemptID = nil
        case .offline(let id):
            guard activeAttemptID == id else { return }
            outcome = .offline
            isRefreshing = false
            refreshSource = nil
            activeAttemptID = nil
        case .connectivityChanged(let isOffline):
            self.isOffline = isOffline
        case .locationUnavailable:
            contextKey = nil
            revision = nil
            isLocationUnavailable = true
            isRefreshing = false
            refreshSource = nil
            activeAttemptID = nil
        case .persistenceUnavailable(let projectionKey):
            guard contextKey == projectionKey else { return }
            isPersistenceUnavailable = true
        case .persistenceRecovered(let projectionKey):
            guard contextKey == projectionKey else { return }
            isPersistenceUnavailable = false
        }
    }

    private mutating func acceptCore(_ record: HomeProjectionRecord) {
        guard record.projectionKey == contextKey,
              revision.map({ record.updatedAt >= $0.core.updatedAt }) ?? true else { return }
        let alerts = revision?.alerts.flatMap { $0.updatedAt > record.updatedAt ? $0 : nil }
        let enrichment = revision?.enrichment.flatMap { $0.updatedAt > record.updatedAt ? $0 : nil }
        revision = HomeVisibleRevision(core: record, alerts: alerts, enrichment: enrichment)
        outcome = .none
        isPersistenceUnavailable = false
    }
}
