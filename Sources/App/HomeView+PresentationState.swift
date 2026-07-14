import ArcusCore
import Foundation

extension HomeView {
    static func selectProjection(
        from projections: [HomeProjectionRecord],
        currentContext: LocationContext?
    ) -> HomeProjectionRecord? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            return projections.first(where: { $0.projectionKey == projectionKey })
        }

        return projections.max(by: { $0.updatedAt < $1.updatedAt })
    }

    static func selectStormSetup(
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

    static func selectStormSetupCurrentResponse(
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

    static func resolveLocationTimeZone(
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

    static func selectProjection(
        from projections: [HomeProjection],
        currentContext: LocationContext?
    ) -> HomeProjection? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            return projections.first(where: { $0.projectionKey == projectionKey })
        }

        return projections.max(by: { $0.updatedAt < $1.updatedAt })
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

    static func preferredSummaryValue<T>(
        projectionValue: T?,
        pipelineValue: T?,
        prefersPipelineValue: Bool
    ) -> T? {
        if prefersPipelineValue {
            return pipelineValue ?? projectionValue
        }
        return projectionValue ?? pipelineValue
    }

    static func preferredCurrentContextValues<T>(
        cachedValues: [T],
        pipelineValues: [T],
        currentContext: LocationContext?,
        pipelineRefreshKey: LocationContext.RefreshKey?
    ) -> [T] {
        guard let currentContext,
              currentContext.refreshKey == pipelineRefreshKey else {
            return cachedValues
        }

        return pipelineValues
    }

    static func shouldRefreshStormSetupSettings(
        previousPreferences: StormSetupPreferences?,
        currentPreferences: StormSetupPreferences
    ) -> Bool {
        previousPreferences != currentPreferences
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
