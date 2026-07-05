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
        guard primary.source.runTime == cachedPayload.modelRunTime else { return nil }
        guard primary.source.validTime == cachedPayload.validTime else { return nil }
        guard primary.source.forecastHour == cachedPayload.forecastHour else { return nil }
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
        guard primary.source.runTime == runTime else { return nil }
        guard primary.source.validTime == validTime else { return nil }
        guard primary.source.forecastHour == forecastHour else { return nil }
        guard primary.freshness.expiresAt > fetchedAt else { return nil }

        return HomeProjectionStormSetupProfileAnalysisPayload(
            response: profileAnalysis.response,
            modelRunTime: primary.source.runTime,
            validTime: primary.source.validTime,
            forecastHour: primary.source.forecastHour,
            fetchedAt: fetchedAt,
            expiresAt: primary.freshness.expiresAt
        )
    }
}
