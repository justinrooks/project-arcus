import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("Today Content State")
@MainActor
struct TodayContentStateTests {
    @Test("header condense progress normalizes and clamps scroll offsets")
    func headerCondenseProgress_normalizesAndClampsScrollOffsets() {
        #expect(TodayHeaderCondenseState.normalizedProgress(for: -20) == 0)
        #expect(TodayHeaderCondenseState.normalizedProgress(for: 40) == 0.5)
        #expect(TodayHeaderCondenseState.normalizedProgress(for: 100) == 1)
    }

    @Test("header condense state does not republish equivalent effective progress")
    func headerCondenseState_doesNotRepublishEquivalentEffectiveProgress() {
        let state = TodayHeaderCondenseState()

        #expect(state.update(scrollOffset: -20) == false)
        #expect(state.update(scrollOffset: 40))
        #expect(state.progress == 0.5)
        #expect(state.update(scrollOffset: 40) == false)
        #expect(state.update(scrollOffset: 100))
        #expect(state.update(scrollOffset: 120) == false)
    }

    @Test("cached refreshing exposes the calm page cue and suppresses section loading branches")
    func cachedRefreshing_exposesCalmCueAndSuppressesSectionLoadingBranches() {
        #expect(TodayContentState.cachedRefreshing.showsCalmUpdatingCue)
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
                todayContentState: .cachedRefreshing,
                isLoading: false,
                isPending: true
            ) == "Outlook details will appear here when available."
        )
    }

    @Test("no cache while resolving maps to the resolving state")
    func noCacheResolving_mapsToResolvingState() {
        #expect(
            TodayContentState.from(
                readinessState: .loadingLocalData,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ) == .noCacheResolving
        )
    }

    @Test("cached content refreshes while online")
    func cachedContentRefreshing_mapsToCachedRefreshingState() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: false
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
                isOffline: true
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

    @Test("stale refreshing keeps cached content visible instead of collapsing to unavailable")
    func staleRefreshing_keepsCachedContentVisible() {
        #expect(TodayContentState.staleRefreshing.showsCalmUpdatingCue)
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
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .loadingLocalData,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: false,
                isLocationUnavailable: false
            )
        )
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
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .ready,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: true,
                isLocationUnavailable: false
            ) == false
        )
    }

    @Test("cached refresh keeps the page calm and suppresses full-content transitions")
    func cachedRefresh_keepsThePageCalm() {
        #expect(TodayContentState.cachedRefreshing.showsCalmUpdatingCue)
        #expect(TodayContentState.cachedRefreshing.suppressesRoutineRefreshMotion)
        #expect(TodayContentState.cachedRefreshing.allowsSectionResolvingTreatment == false)
        #expect(TodayContentState.cachedRefreshing.showsResolvingSurface == false)
        #expect(TodayContentState.staleRefreshing.suppressesRoutineRefreshMotion == false)
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .ready,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: true,
                isLocationUnavailable: false
            ) == false
        )
    }

    @Test("stale cache keeps useful content visible during offline refresh")
    func staleCache_keepsUsefulContentVisible() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: true
            ) == .staleRefreshing
        )
        #expect(TodayContentState.staleRefreshing.showsCalmUpdatingCue)
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
