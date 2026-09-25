import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("Today Content State")
@MainActor
struct TodayContentStateTests {
    @Test("cached manual refresh preserves content and suppresses section loading branches")
    func cachedRefreshing_exposesCalmCueAndSuppressesSectionLoadingBranches() {
        #expect(TodayContentState.cachedRefreshing.showsCalmUpdatingCue == false)
        #expect(TodayContentState.cachedRefreshing.allowsSectionResolvingTreatment == false)
        #expect(TodayContentState.cachedRefreshing.suppressesRoutineRefreshMotion)
        #expect(TodayContentState.noCacheResolving.suppressesRoutineRefreshMotion == false)

        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .cachedRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: Date(timeIntervalSince1970: 1_000),
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ).presentationState == .empty
        )

        #expect(
            SummaryAwarenessPrimaryState.resolve(
                stormRisk: nil,
                severeRisk: nil,
                fireRisk: nil,
                alerts: [],
                todayContentState: .cachedRefreshing,
                isStormRiskResolving: true,
                isSevereRiskResolving: true,
                isFireRiskResolving: true,
                isOffline: false
            ) == .quiet
        )

        #expect(
            OutlookSummaryCard.outlookSummaryText(
                outlook: nil,
                presentationState: .unavailable
            ) == "Outlook information is unavailable. Try again later."
        )
    }

    @Test("Today Outlook summary distinguishes accepted empty, unavailable, loading, and retained failure")
    func outlookSummarySemanticStates() {
        #expect(OutlookSummaryCard.outlookSummaryText(outlook: nil, presentationState: .loading)
                == "Checking outlook details…")
        #expect(OutlookSummaryCard.outlookSummaryText(outlook: nil, presentationState: .empty(.current))
                .contains("last confirmed update"))
        #expect(OutlookSummaryCard.outlookSummaryText(outlook: nil, presentationState: .unavailable)
                .contains("unavailable"))
        #expect(OutlookSummaryCard.statusText(for: .empty(.refreshing))?.contains("Checking for an updated") == true)
        #expect(OutlookSummaryCard.statusText(for: .populated(.failed))?.contains("could not be updated") == true)
    }

    @Test("no cache while resolving maps to the resolving state")
    func noCacheResolving_mapsToResolvingState() {
        let readinessResolving = TodayContentState.from(
            readinessState: .loadingLocalData,
            hasCachedContent: false,
            hasLiveContent: false,
            isRefreshing: false,
            isOffline: false
        )
        #expect(readinessResolving == .noCacheResolving)
        #expect(readinessResolving.showsResolvingSurface)
        #expect(readinessResolving.suppressesRoutineRefreshMotion == false)

        let refreshResolving = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: false,
            hasLiveContent: false,
            isRefreshing: true,
            isOffline: false
        )
        #expect(refreshResolving == .noCacheResolving)
        #expect(refreshResolving.showsResolvingSurface)
    }

    @Test("cached content refreshes while online")
    func cachedContentRefreshing_mapsToCachedRefreshingState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: false,
                isManualRefreshInFlight: true
            ) == .cachedRefreshing
        )
    }

    @Test("cached content remains current while idle and online")
    func cachedContentIdle_mapsToCurrentState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .current
        )
    }

    @Test("live fallback content without cache is still current when idle")
    func liveFallbackContentIdle_mapsToCurrentState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: false,
                hasLiveContent: true,
                isRefreshing: false,
                isOffline: false
            ) == .current
        )
    }

    @Test("cached content becomes stale while refreshing offline")
    func cachedContentRefreshingOffline_mapsToStaleRefreshingState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: true,
                isManualRefreshInFlight: true
            ) == .staleRefreshing
        )
    }

    @Test("cached content becomes degraded while offline and idle")
    func cachedContentOfflineIdle_mapsToDegradedState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: true
            ) == .degraded
        )
    }

    @Test("stale manual refreshing keeps cached content visible instead of collapsing to unavailable")
    func staleRefreshing_keepsCachedContentVisible() {
        #expect(TodayContentState.staleRefreshing.showsCalmUpdatingCue == false)
        #expect(TodayContentState.staleRefreshing.showsResolvingSurface == false)
        #expect(
            LocalAlertsDisplayState.from(
                todayContentState: .staleRefreshing,
                hasCachedProjection: true,
                isCurrentContextResolvedInPipeline: false,
                lastHotAlertsLoadAt: Date(timeIntervalSince1970: 1_000),
                hasActiveAlerts: false,
                isLocationUnavailable: false
            ).presentationState == .empty
        )
    }

    @Test("cached refresh activity distinguishes quiet automatic work from manual outcomes")
    func cachedRefreshActivity_distinguishesAutomaticAndManualOutcomes() {
        let automatic = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: true,
            hasLiveContent: false,
            isRefreshing: true,
            isOffline: false
        )
        #expect(automatic == .quietRefreshing)
        #expect(automatic.manualRefreshStatusMessage == nil)
        #expect(automatic.allowsSectionResolvingTreatment == false)

        let manual = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: true,
            hasLiveContent: false,
            isRefreshing: true,
            isOffline: false,
            isManualRefreshInFlight: true
        )
        #expect(manual == .cachedRefreshing)
        #expect(manual.manualRefreshStatusMessage == nil)
        #expect(manual.showsCalmUpdatingCue == false)

        let offlineManual = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: true,
            hasLiveContent: false,
            isRefreshing: true,
            isOffline: true,
            isManualRefreshInFlight: true
        )
        #expect(offlineManual == .staleRefreshing)
        #expect(offlineManual.manualRefreshStatusMessage == nil)

        let failedManual = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: true,
            hasLiveContent: false,
            isRefreshing: false,
            isOffline: false,
            didManualRefreshFail: true
        )
        #expect(failedManual == .refreshFailedWithCache)
        #expect(failedManual.manualRefreshStatusMessage == "Couldn't update. Showing saved conditions.")
        #expect(failedManual.showsCalmUpdatingCue)

        let offlineAfterFailure = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: true,
            hasLiveContent: false,
            isRefreshing: false,
            isOffline: true,
            didManualRefreshFail: true
        )
        #expect(offlineAfterFailure == .degraded)
    }

    @Test("no cache and no content maps to unavailable")
    func noCacheNoContent_mapsToUnavailableState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .unavailable
        )
    }
}


@Suite("Today Surface State Flow")
@MainActor
struct TodaySurfaceStateFlowTests {
    private let loadedAt = Date(timeIntervalSince1970: 1_000)

    @Test("first launch without cache keeps the calm resolving surface")
    func firstLaunchWithoutCache_keepsCalmResolvingSurface() {
        let state = TodayContentState.from(
            readinessState: .loadingLocalData,
            hasCachedContent: false,
            hasLiveContent: false,
            isRefreshing: false,
            isOffline: false
        )

        #expect(state == .noCacheResolving)
        #expect(state.showsResolvingSurface)
        #expect(state.showsCalmUpdatingCue == false)
        #expect(state.allowsSectionResolvingTreatment)
    }

    @Test("valid cached launch stays on content and avoids resolving theater")
    func validCachedLaunch_avoidsResolvingTheater() {
        let state = TodayContentState.from(
            readinessState: .ready,
            hasCachedContent: true,
            hasLiveContent: false,
            isRefreshing: false,
            isOffline: false
        )

        #expect(state == .current)
        #expect(state.showsResolvingSurface == false)
        #expect(state.showsCalmUpdatingCue == false)
        #expect(state.suppressesRoutineRefreshMotion == false)
    }

    @Test("cached refresh keeps the page calm and suppresses full-content transitions")
    func cachedRefresh_keepsThePageCalm() {
        #expect(TodayContentState.cachedRefreshing.showsCalmUpdatingCue == false)
        #expect(TodayContentState.cachedRefreshing.suppressesRoutineRefreshMotion)
        #expect(TodayContentState.cachedRefreshing.allowsSectionResolvingTreatment == false)
        #expect(TodayContentState.cachedRefreshing.showsResolvingSurface == false)
        #expect(TodayContentState.staleRefreshing.suppressesRoutineRefreshMotion)
    }

    @Test("stale cache keeps useful content visible during offline refresh")
    func staleCache_keepsUsefulContentVisible() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: true,
                isManualRefreshInFlight: true
            ) == .staleRefreshing
        )
        #expect(TodayContentState.staleRefreshing.showsCalmUpdatingCue == false)
        #expect(TodayContentState.staleRefreshing.showsResolvingSurface == false)
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: true,
                isResolving: false
            ) == .stale
        )

        let localAlertsState = LocalAlertsDisplayState.from(
            todayContentState: .staleRefreshing,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: false,
            isLocationUnavailable: false
        )

        #expect(localAlertsState == .staleOrDegraded(content: .empty))
        #expect(localAlertsState.presentationState == .empty)
        #expect(localAlertsState.showsOfflineStatusCopy == false)
    }

    @Test("degraded cache keeps useful content visible when refresh is idle offline")
    func degradedCache_keepsUsefulContentVisible() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: true
            ) == .degraded
        )
        #expect(TodayContentState.degraded.showsCalmUpdatingCue == false)
        #expect(TodayContentState.degraded.showsResolvingSurface == false)
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: true,
                isResolving: false
            ) == .stale
        )

        let localAlertsState = LocalAlertsDisplayState.from(
            todayContentState: .degraded,
            hasCachedProjection: true,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: loadedAt,
            hasActiveAlerts: true,
            isLocationUnavailable: false
        )

        #expect(localAlertsState == .staleOrDegraded(content: .populated))
        #expect(localAlertsState.presentationState == .alerts)
        #expect(localAlertsState.showsOfflineStatusCopy)
    }

    @Test("unavailable only appears when no useful data exists")
    func unavailable_requiresNoUsefulData() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .unavailable
        )
        #expect(TodayContentState.unavailable.showsCalmUpdatingCue == false)
        #expect(TodayContentState.unavailable.showsResolvingSurface == false)
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: false,
                isResolving: true
            ) == .unavailable
        )

        let localAlertsState = LocalAlertsDisplayState.from(
            todayContentState: .unavailable,
            hasCachedProjection: false,
            isCurrentContextResolvedInPipeline: false,
            lastHotAlertsLoadAt: nil,
            hasActiveAlerts: false,
            isLocationUnavailable: false
        )

        #expect(localAlertsState == .unavailable(reason: .noUsefulAlertState))
        #expect(localAlertsState.presentationState == .unavailable)
    }

    @Test("foreground-return weather retention stays aligned at the Today level")
    func foregroundReturn_weatherRetentionStaysAligned() {
        let weather = SummaryWeather(
            temperature: Measurement(value: 76, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: .now,
            dewPoint: Measurement(value: 50, unit: .fahrenheit),
            humidity: 0.35,
            windSpeed: Measurement(value: 8, unit: .milesPerHour),
            windGust: nil,
            windDirection: "NW",
            pressure: Measurement(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
        let identity = SummaryWeatherLocationIdentity(
            snapshot: .init(
                coordinates: .init(latitude: 39.7392, longitude: -104.9903),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: nil
            )
        )

        let retained = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: identity,
            weatherLocationIdentity: identity
        )

        #expect(retained.weather == weather)
        #expect(retained.locationIdentity == identity)
    }
}


@Suite("Today Visible Weather State")
struct TodayVisibleWeatherStateTests {
    @Test("keeps displayed weather during refresh when location identity is unchanged")
    func keepsDisplayedWeather_sameIdentityRefreshing() {
        let weather = makeWeather()
        let identity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: identity,
            weatherLocationIdentity: identity
        )

        #expect(resolved.weather == weather)
        #expect(resolved.locationIdentity == identity)
    }

    @Test("clears displayed weather during refresh when location identity changes")
    func clearsDisplayedWeather_changedIdentityRefreshing() {
        let weather = makeWeather()
        let previousIdentity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")
        let newIdentity = makeIdentity(latitude: 34.0522, longitude: -118.2437, placemark: "Los Angeles, CA")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: previousIdentity,
            weatherLocationIdentity: newIdentity
        )

        #expect(resolved.weather == nil)
        #expect(resolved.locationIdentity == nil)
    }

    @Test("clears displayed weather when refresh is inactive even if identity matches")
    func clearsDisplayedWeather_sameIdentityNotRefreshing() {
        let weather = makeWeather()
        let identity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: weather,
            isRefreshing: false,
            displayedWeatherLocationIdentity: identity,
            weatherLocationIdentity: identity
        )

        #expect(resolved.weather == nil)
        #expect(resolved.locationIdentity == nil)
    }

    @Test("prefers live weather and current location identity")
    func prefersLiveWeatherAndCurrentIdentity() {
        let liveWeather = makeWeather(temperatureF: 64)
        let previousWeather = makeWeather(temperatureF: 72)
        let previousIdentity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")
        let currentIdentity = makeIdentity(latitude: 34.0522, longitude: -118.2437, placemark: "Los Angeles, CA")

        let resolved = TodayVisibleWeatherState.resolve(
            liveWeather: liveWeather,
            displayedWeather: previousWeather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: previousIdentity,
            weatherLocationIdentity: currentIdentity
        )

        #expect(resolved.weather == liveWeather)
        #expect(resolved.locationIdentity == currentIdentity)
    }

    @Test("rendered weather clears immediately when location identity changes during refresh")
    func renderedWeather_clearsImmediatelyOnIdentityChange() {
        let retainedWeather = makeWeather()
        let oldIdentity = makeIdentity(latitude: 39.7392, longitude: -104.9903, placemark: "Denver, CO")
        let newIdentity = makeIdentity(latitude: 47.6062, longitude: -122.3321, placemark: "Seattle, WA")

        let rendered = TodayVisibleWeatherState.resolve(
            liveWeather: nil,
            displayedWeather: retainedWeather,
            isRefreshing: true,
            displayedWeatherLocationIdentity: oldIdentity,
            weatherLocationIdentity: newIdentity
        )

        #expect(rendered.weather == nil)
    }

    private func makeIdentity(latitude: Double, longitude: Double, placemark: String) -> SummaryWeatherLocationIdentity {
        SummaryWeatherLocationIdentity(
            snapshot: .init(
                coordinates: .init(latitude: latitude, longitude: longitude),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: placemark,
                h3Cell: nil
            )
        )
    }

    private func makeWeather(temperatureF: Double = 72) -> SummaryWeather {
        SummaryWeather(
            temperature: Measurement(value: temperatureF, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: .now,
            dewPoint: Measurement(value: 50, unit: .fahrenheit),
            humidity: 0.35,
            windSpeed: Measurement(value: 8, unit: .milesPerHour),
            windGust: nil,
            windDirection: "NW",
            pressure: Measurement(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
    }
}
