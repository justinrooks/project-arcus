import Foundation

struct StormSetupProfileAnalysisPolicy {
    static func shouldFetch(
        preferences: StormSetupPreferences,
        primary: StormSetupDTO?,
        cachedPayload: HomeProjectionStormSetupProfileAnalysisPayload?,
        now: Date
    ) -> Bool {
        guard preferences.effectiveDetailedIngredientsEnabled else { return false }
        return usableCachedPayload(
            preferences: preferences,
            primary: primary,
            cachedPayload: cachedPayload,
            now: now
        ) == nil
    }

    static func usableCachedPayload(
        preferences: StormSetupPreferences,
        primary: StormSetupDTO?,
        cachedPayload: HomeProjectionStormSetupProfileAnalysisPayload?,
        now: Date
    ) -> HomeProjectionStormSetupProfileAnalysisPayload? {
        guard preferences.effectiveDetailedIngredientsEnabled else { return nil }
        guard let primary, let cachedPayload else { return nil }
        guard let runTime = primary.source.runTime else { return nil }
        guard let validTime = primary.source.validTime else { return nil }
        guard let forecastHour = primary.source.forecastHour else { return nil }
        guard runTime == cachedPayload.modelRunTime else { return nil }
        guard validTime == cachedPayload.validTime else { return nil }
        guard forecastHour == cachedPayload.forecastHour else { return nil }
        guard primary.freshness.expiresAt > now else { return nil }
        guard cachedPayload.expiresAt > now else { return nil }
        return cachedPayload
    }

    static func makePersistedPayload(
        from profileAnalysis: StormSetupProfileAnalysisDTO,
        primary: StormSetupDTO,
        fetchedAt: Date
    ) -> HomeProjectionStormSetupProfileAnalysisPayload? {
        guard let request = profileAnalysis.request else { return nil }
        guard let runTime = request.runTime else { return nil }
        guard let validTime = request.validTime else { return nil }
        guard let forecastHour = request.forecastHour else { return nil }
        guard let primaryRunTime = primary.source.runTime else { return nil }
        guard let primaryValidTime = primary.source.validTime else { return nil }
        guard let primaryForecastHour = primary.source.forecastHour else { return nil }
        guard primaryRunTime == runTime else { return nil }
        guard primaryValidTime == validTime else { return nil }
        guard primaryForecastHour == forecastHour else { return nil }
        guard primary.freshness.expiresAt > fetchedAt else { return nil }

        return HomeProjectionStormSetupProfileAnalysisPayload(
            response: profileAnalysis.response,
            modelRunTime: primaryRunTime,
            validTime: primaryValidTime,
            forecastHour: primaryForecastHour,
            fetchedAt: fetchedAt,
            expiresAt: primary.freshness.expiresAt
        )
    }
}
