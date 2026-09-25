import ArcusCore
import Foundation

extension HomeView {
    /// The complete location-scoped value visible on the Today and Alerts surfaces.
    ///
    /// This is deliberately a value transformation: callers copy their current persisted and
    /// pipeline inputs here after sampling time, while ownership of those inputs remains outside.
    struct HomePresentationSnapshot {
        let projection: HomeProjectionRecord?
        let locationSnapshot: LocationSnapshot?
        let stormRisk: StormRiskLevel?
        let severeRisk: SevereWeatherThreat?
        let fireRisk: FireRiskLevel?
        let weather: SummaryWeather?
        let airQuality: AirQualityCurrentResponse?
        let mesos: [MdDTO]
        let alerts: [AlertDTO]
        let lastAcceptedAlertsLoadAt: Date?
        let stormSetup: StormSetupDTO?
        let stormSetupCurrentResponse: StormSetupCurrentResponse?
        let locationTimeZone: TimeZone
        let isCurrentContextResolvedInPipeline: Bool
        let isCurrentContextCommittedAlertSnapshot: Bool

        init(
            visibleRevision: HomeVisibleRevision?,
            newestStartupProjection: HomeProjectionRecord?,
            currentContext: LocationContext?,
            pipelineSnap: LocationSnapshot?,
            pipelineStormRisk: StormRiskLevel?,
            pipelineSevereRisk: SevereWeatherThreat?,
            pipelineFireRisk: FireRiskLevel?,
            pipelineWeather: SummaryWeather?,
            pipelineAirQuality: AirQualityCurrentResponse?,
            pipelineMesos: [MdDTO],
            pipelineAlerts: [AlertDTO],
            resolvedLocationScopedRefreshKey: LocationContext.RefreshKey?,
            alertSnapshotRefreshKey: LocationContext.RefreshKey?,
            pipelineStormSetup: StormSetupDTO?,
            pipelineStormSetupCurrentResponse: StormSetupCurrentResponse?,
            stormSetupRefreshKey: LocationContext.RefreshKey?,
            isUITestStaticMode: Bool,
            now: Date
        ) {
            let projection = visibleRevision?.core
            let currentRefreshKey = currentContext?.refreshKey
            let isResolved = currentRefreshKey == resolvedLocationScopedRefreshKey && currentRefreshKey != nil
            let currentAlertsAreCommitted = currentRefreshKey == alertSnapshotRefreshKey && currentRefreshKey != nil
            let enrichment = visibleRevision?.enrichment ?? projection
            let response = HomeView.selectStormSetupCurrentResponse(
                projection: enrichment,
                currentContext: currentContext,
                pipelineValue: isUITestStaticMode ? pipelineStormSetupCurrentResponse : nil,
                pipelineRefreshKey: isUITestStaticMode ? stormSetupRefreshKey : nil,
                now: now
            )

            self.projection = projection
            self.locationSnapshot = projection?.locationSnapshot ?? (isUITestStaticMode ? pipelineSnap : nil)
            self.stormRisk = visibleRevision?.stormRisk ?? (isUITestStaticMode ? pipelineStormRisk : nil)
            self.severeRisk = visibleRevision?.severeRisk ?? (isUITestStaticMode ? pipelineSevereRisk : nil)
            self.fireRisk = visibleRevision?.fireRisk ?? (isUITestStaticMode ? pipelineFireRisk : nil)
            self.weather = visibleRevision?.weather ?? (isUITestStaticMode ? pipelineWeather : nil)
            self.airQuality = visibleRevision?.airQuality ?? (isUITestStaticMode ? pipelineAirQuality : nil)
            self.mesos = isUITestStaticMode && !pipelineMesos.isEmpty
                ? pipelineMesos
                : visibleRevision?.activeMesos ?? []
            self.alerts = isUITestStaticMode && !pipelineAlerts.isEmpty
                ? pipelineAlerts
                : visibleRevision?.activeAlerts ?? []
            self.lastAcceptedAlertsLoadAt = (visibleRevision?.alerts ?? projection)?.lastHotAlertsLoadAt
            self.stormSetupCurrentResponse = response
            self.stormSetup = response.map(StormSetupDTO.init(response:)) ?? HomeView.selectStormSetup(
                projection: enrichment,
                currentContext: currentContext,
                pipelineValue: isUITestStaticMode ? pipelineStormSetup : nil,
                pipelineRefreshKey: isUITestStaticMode ? stormSetupRefreshKey : nil,
                now: now
            )
            self.locationTimeZone = HomeView.resolveLocationTimeZone(
                selectedProjection: projection,
                currentContext: currentContext,
                newestStartupProjection: newestStartupProjection
            )
            self.isCurrentContextResolvedInPipeline = isResolved
            self.isCurrentContextCommittedAlertSnapshot = currentAlertsAreCommitted
        }
    }

    nonisolated static func selectProjection(
        from projections: [HomeProjectionRecord],
        currentContext: LocationContext?
    ) -> HomeProjectionRecord? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            return projections.first(where: {
                $0.projectionKey == projectionKey && $0.isDisplayReady
            })
        }

        return projections
            .filter(\.isDisplayReady)
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    nonisolated static func selectStormSetup(
        projection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        pipelineValue: StormSetupDTO?,
        pipelineRefreshKey: LocationContext.RefreshKey?,
        now: Date
    ) -> StormSetupDTO? {
        if let currentContext {
            let currentRefreshKey = currentContext.refreshKey
            if pipelineRefreshKey == currentRefreshKey,
               let pipelineValue,
               pipelineValue.freshness.expiresAt > now,
               pipelineValue.h3Cell == currentContext.h3Cell {
                return pipelineValue
            }

            guard let projection,
                  projection.projectionKey == HomeProjection.projectionKey(for: currentContext),
                  let stormSetup = projection.stormSetup,
                  stormSetup.freshness.expiresAt > now,
                  stormSetup.h3Cell == currentContext.h3Cell else {
                return nil
            }

            return stormSetup
        }

        guard let stormSetup = projection?.stormSetup,
              stormSetup.freshness.expiresAt > now else {
            return nil
        }

        return stormSetup
    }

    nonisolated static func selectStormSetupCurrentResponse(
        projection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        pipelineValue: StormSetupCurrentResponse?,
        pipelineRefreshKey: LocationContext.RefreshKey?,
        now: Date
    ) -> StormSetupCurrentResponse? {
        if let currentContext {
            let currentRefreshKey = currentContext.refreshKey
            if pipelineRefreshKey == currentRefreshKey,
               let pipelineValue,
               pipelineValue.setup.freshness.expiresAt > now,
               pipelineValue.setup.h3Cell == currentContext.h3Cell {
                return pipelineValue
            }

            guard let projection,
                  projection.projectionKey == HomeProjection.projectionKey(for: currentContext),
                  let response = projection.stormSetupCurrentResponse,
                  response.setup.freshness.expiresAt > now,
                  response.setup.h3Cell == currentContext.h3Cell else {
                return nil
            }
            return response
        }

        guard let response = projection?.stormSetupCurrentResponse,
              response.setup.freshness.expiresAt > now else {
            return nil
        }
        return response
    }

    nonisolated static func resolveLocationTimeZone(
        selectedProjection: HomeProjectionRecord?,
        currentContext: LocationContext?,
        newestStartupProjection: HomeProjectionRecord?,
        fallback: TimeZone = .autoupdatingCurrent
    ) -> TimeZone {
        if let timeZoneIdentifier = selectedProjection?.timeZoneId,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        if let currentContext,
           let timeZoneIdentifier = currentContext.grid.timeZoneId,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        if currentContext == nil,
           let timeZoneIdentifier = newestStartupProjection?.timeZoneId,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }

        return fallback
    }

    nonisolated static func selectProjection(
        from projections: [HomeProjection],
        currentContext: LocationContext?
    ) -> HomeProjection? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            return projections.first(where: {
                $0.projectionKey == projectionKey && $0.record.isDisplayReady
            })
        }

        return projections
            .filter { $0.record.isDisplayReady }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    static func showsBootstrapLoading(
        readinessState: SummaryReadinessState,
        isRefreshInFlight: Bool,
        hasProjection: Bool
    ) -> Bool {
        readinessState != .locationUnavailable &&
        hasProjection == false &&
        (isRefreshInFlight || readinessState != .ready)
    }

    static func shouldScheduleStormSetupSettingsRefresh(
        previousPreferences: StormSetupPreferences,
        currentPreferences: StormSetupPreferences,
        hasCurrentLocationContext: Bool,
        isPreviewMode: Bool,
        isUITestStaticMode: Bool
    ) -> Bool {
        guard hasCurrentLocationContext, isPreviewMode == false, isUITestStaticMode == false else {
            return false
        }

        let stormSetupWasEnabled = previousPreferences.stormSetupEnabled
        let stormSetupIsEnabled = currentPreferences.stormSetupEnabled
        let detailedIngredientsWereEnabled = previousPreferences.detailedIngredientsEnabled
        let detailedIngredientsAreEnabled = currentPreferences.detailedIngredientsEnabled

        return (stormSetupWasEnabled == false && stormSetupIsEnabled) ||
            (detailedIngredientsWereEnabled == false && detailedIngredientsAreEnabled && stormSetupIsEnabled)
    }

    static func preferredOutlooks(
        cachedOutlooks: [ConvectiveOutlookDTO],
        liveOutlooks: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus,
        hasAcceptedEmptySnapshot: Bool = false
    ) -> [ConvectiveOutlookDTO] {
        if hasAcceptedEmptySnapshot { return [] }
        if case .success(hasContent: false) = refreshStatus { return [] }
        return liveOutlooks.isEmpty ? cachedOutlooks : liveOutlooks
    }
}
