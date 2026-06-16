//
//  TodayVisibleWeatherState.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

struct TodayVisibleWeatherState: Sendable, Equatable {
    var weather: SummaryWeather?
    var locationIdentity: SummaryWeatherLocationIdentity?

    init(
        weather: SummaryWeather? = nil,
        locationIdentity: SummaryWeatherLocationIdentity? = nil
    ) {
        self.weather = weather
        self.locationIdentity = locationIdentity
    }

    static func resolve(
        liveWeather: SummaryWeather?,
        displayedWeather: SummaryWeather?,
        isRefreshing: Bool,
        displayedWeatherLocationIdentity: SummaryWeatherLocationIdentity?,
        weatherLocationIdentity: SummaryWeatherLocationIdentity?
    ) -> TodayVisibleWeatherState {
        if let liveWeather {
            return .init(weather: liveWeather, locationIdentity: weatherLocationIdentity)
        }

        guard isRefreshing,
              displayedWeather != nil,
              displayedWeatherLocationIdentity == weatherLocationIdentity else {
            return .init()
        }

        return .init(
            weather: displayedWeather,
            locationIdentity: displayedWeatherLocationIdentity
        )
    }
}
