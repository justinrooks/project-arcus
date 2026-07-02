//
//  WeatherClient.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/18/26.
//

import CoreLocation
import Foundation
import WeatherKit
import OSLog

actor WeatherClient {
    private let logger = Logger.providersWeatherKit
    private let service = WeatherService.shared

    func currentWeather(for location: CLLocation) async -> HomeWeatherRefreshResult {
        do {
            logger.info("WeatherKit request started mode=\(HTTPExecutionMode.current.logName, privacy: .public)")
            let currentWeather = try await self.service.weather(for: location, including: .current)
            logger.info("WeatherKit request completed result=success")
            
            return .success(.init(
                temperature: currentWeather.temperature,
                symbolName: currentWeather.symbolName,
                conditionText: currentWeather.condition.description,
                asOf: .now,
                dewPoint: currentWeather.dewPoint,
                humidity: currentWeather.humidity,
                windSpeed: currentWeather.wind.speed,
                windGust: currentWeather.wind.gust,
                windDirection: currentWeather.wind.compassDirection.abbreviation,
                pressure: currentWeather.pressure,
                pressureTrend: currentWeather.pressureTrend.description
            ))
        } catch {
            logger.error("WeatherKit request completed result=failure error=\(error, privacy: .public)")
            return .failure
        }
    }
    
    func weatherAttribution() async -> WeatherAttribution? {
        do {
            let attr = try await self.service.attribution
            return attr
        } catch {
            logger.error("WeatherKit attribution failed: \(error, privacy: .public)")
            return nil
        }
    }
}
