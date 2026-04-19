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
    var stormRisk: StormRiskLevel?
    var severeRisk: SevereWeatherThreat?
    var fireRisk: FireRiskLevel?
    var mesos: [MdDTO]
    var watches: [WatchRowDTO]
    var outlooks: [ConvectiveOutlookDTO]
    var latestOutlook: ConvectiveOutlookDTO?
    var freshness: HomeFreshnessState

    init(
        locationSnapshot: LocationSnapshot? = nil,
        refreshKey: LocationContext.RefreshKey? = nil,
        weather: SummaryWeather? = nil,
        stormRisk: StormRiskLevel? = nil,
        severeRisk: SevereWeatherThreat? = nil,
        fireRisk: FireRiskLevel? = nil,
        mesos: [MdDTO] = [],
        watches: [WatchRowDTO] = [],
        outlooks: [ConvectiveOutlookDTO] = [],
        latestOutlook: ConvectiveOutlookDTO? = nil,
        freshness: HomeFreshnessState = .init()
    ) {
        self.locationSnapshot = locationSnapshot
        self.refreshKey = refreshKey
        self.weather = weather
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.mesos = mesos
        self.watches = watches
        self.outlooks = outlooks
        self.latestOutlook = latestOutlook
        self.freshness = freshness
    }

    static let empty = HomeSnapshot()
}
