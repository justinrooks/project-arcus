//
//  HomeSnapshot.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import ArcusCore

enum HomeStormSetupRefreshResult: Sendable, Equatable {
    case skipped
    case success
    case failure
    case timeout
    case cancelled
    case h3Mismatch
}

struct HomeSnapshot: Sendable, Equatable {
    var locationSnapshot: LocationSnapshot?
    var refreshKey: LocationContext.RefreshKey?
    var weather: SummaryWeather?
    var weatherRefreshResult: HomeWeatherRefreshResult
    var stormSetup: StormSetupDTO?
    var stormSetupRefreshResult: HomeStormSetupRefreshResult
    var stormSetupCurrentResponse: StormSetupCurrentResponse?
    var airQuality: AirQualityCurrentResponse?
    var stormRisk: StormRiskLevel?
    var severeRisk: SevereWeatherThreat?
    var fireRisk: FireRiskLevel?
    var mesos: [MdDTO]
    var alerts: [AlertDTO]
    var outlooks: [ConvectiveOutlookDTO]
    var latestOutlook: ConvectiveOutlookDTO?
    var freshness: HomeFreshnessState

    init(
        locationSnapshot: LocationSnapshot? = nil,
        refreshKey: LocationContext.RefreshKey? = nil,
        weather: SummaryWeather? = nil,
        weatherRefreshResult: HomeWeatherRefreshResult = .skipped,
        stormSetup: StormSetupDTO? = nil,
        stormSetupRefreshResult: HomeStormSetupRefreshResult = .skipped,
        stormSetupCurrentResponse: StormSetupCurrentResponse? = nil,
        airQuality: AirQualityCurrentResponse? = nil,
        stormRisk: StormRiskLevel? = nil,
        severeRisk: SevereWeatherThreat? = nil,
        fireRisk: FireRiskLevel? = nil,
        mesos: [MdDTO] = [],
        alerts: [AlertDTO] = [],
        outlooks: [ConvectiveOutlookDTO] = [],
        latestOutlook: ConvectiveOutlookDTO? = nil,
        freshness: HomeFreshnessState = .init()
    ) {
        self.locationSnapshot = locationSnapshot
        self.refreshKey = refreshKey
        self.weather = weather
        self.weatherRefreshResult = weatherRefreshResult
        self.stormSetup = stormSetup
        self.stormSetupRefreshResult = stormSetupRefreshResult
        self.stormSetupCurrentResponse = stormSetupCurrentResponse
        self.airQuality = airQuality
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.mesos = mesos
        self.alerts = alerts
        self.outlooks = outlooks
        self.latestOutlook = latestOutlook
        self.freshness = freshness
    }

    static let empty = HomeSnapshot()
}
