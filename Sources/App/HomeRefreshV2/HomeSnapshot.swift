//
//  HomeSnapshot.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

struct HomeSnapshot: Sendable, Equatable {
    var locationSnapshot: LocationSnapshot?
    var refreshKey: LocationContext.RefreshKey?
    var weather: SummaryWeather?
    var weatherWasRefreshed: Bool
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
        weatherWasRefreshed: Bool = false,
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
        self.weatherWasRefreshed = weatherWasRefreshed
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
