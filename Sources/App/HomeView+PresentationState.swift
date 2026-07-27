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
        let stormSetup: StormSetupDTO?
        let stormSetupCurrentResponse: StormSetupCurrentResponse?
        let locationTimeZone: TimeZone
        let isCurrentContextResolvedInPipeline: Bool
        let isCurrentContextCommittedAlertSnapshot: Bool

        init(
            projections: [HomeProjectionRecord],
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
            let projection = HomeView.selectProjection(from: projections, currentContext: currentContext)
            let currentRefreshKey = currentContext?.refreshKey
            let isResolved = currentRefreshKey == resolvedLocationScopedRefreshKey && currentRefreshKey != nil
            let currentAlertsAreCommitted = currentRefreshKey == alertSnapshotRefreshKey && currentRefreshKey != nil
            let response = HomeView.selectStormSetupCurrentResponse(
                projection: projection,
                currentContext: currentContext,
                pipelineValue: pipelineStormSetupCurrentResponse,
                pipelineRefreshKey: stormSetupRefreshKey,
                now: now
            )

            self.projection = projection
            self.locationSnapshot = HomeView.preferredSummaryValue(
                projectionValue: projection?.locationSnapshot,
                pipelineValue: pipelineSnap,
                prefersPipelineValue: isResolved
            )
            self.stormRisk = HomeView.preferredSummaryValue(
                projectionValue: projection?.stormRisk,
                pipelineValue: pipelineStormRisk,
                prefersPipelineValue: isResolved
            )
            self.severeRisk = HomeView.preferredSummaryValue(
                projectionValue: projection?.severeRisk,
                pipelineValue: pipelineSevereRisk,
                prefersPipelineValue: isResolved
            )
            self.fireRisk = HomeView.preferredSummaryValue(
                projectionValue: projection?.fireRisk,
                pipelineValue: pipelineFireRisk,
                prefersPipelineValue: isResolved
            )
            self.weather = HomeView.preferredSummaryValue(
                projectionValue: projection?.weather,
                pipelineValue: pipelineWeather,
                prefersPipelineValue: isResolved
            )
            self.airQuality = isResolved ? pipelineAirQuality : nil
            self.mesos = isUITestStaticMode && !pipelineMesos.isEmpty
                ? pipelineMesos
                : (currentAlertsAreCommitted ? pipelineMesos : projection?.activeMesos ?? [])
            self.alerts = isUITestStaticMode && !pipelineAlerts.isEmpty
                ? pipelineAlerts
                : (currentAlertsAreCommitted ? pipelineAlerts : projection?.activeAlerts ?? [])
            self.stormSetupCurrentResponse = response
            self.stormSetup = response.map(StormSetupDTO.init(response:)) ?? HomeView.selectStormSetup(
                projection: projection,
                currentContext: currentContext,
                pipelineValue: pipelineStormSetup,
                pipelineRefreshKey: stormSetupRefreshKey,
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
                $0.projectionKey == projectionKey && isDisplayReady($0)
            })
        }

        return projections
            .filter(isDisplayReady)
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
                $0.projectionKey == projectionKey && isDisplayReady($0.record)
            })
        }

        return projections
            .filter { isDisplayReady($0.record) }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    nonisolated private static func isDisplayReady(_ projection: HomeProjectionRecord) -> Bool {
        projection.lastSlowProductsLoadAt != nil &&
        projection.lastHotAlertsLoadAt != nil
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

    nonisolated static func preferredSummaryValue<T>(
        projectionValue: T?,
        pipelineValue: T?,
        prefersPipelineValue: Bool
    ) -> T? {
        if prefersPipelineValue {
            return pipelineValue ?? projectionValue
        }
        return projectionValue ?? pipelineValue
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
        liveOutlooks: [ConvectiveOutlookDTO]
    ) -> [ConvectiveOutlookDTO] {
        liveOutlooks.isEmpty ? cachedOutlooks : liveOutlooks
    }

    static func preferredOutlook(
        cachedOutlook: ConvectiveOutlookDTO?,
        liveOutlooks: [ConvectiveOutlookDTO],
        liveOutlook: ConvectiveOutlookDTO?
    ) -> ConvectiveOutlookDTO? {
        liveOutlooks.first ?? cachedOutlook ?? liveOutlook
    }
}
