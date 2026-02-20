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

    func currentWeather(for location: CLLocation) async -> SummaryWeather? {
        do {
            logger.info("Fetching conditions from WeatherKit")
            let currentWeather = try await self.service.weather(for: location, including: .current)
            
            return .init(
                temperature: currentWeather.temperature,
                symbolName: currentWeather.symbolName,
                conditionText: currentWeather.condition.description,
                asOf: .now
            )
        } catch {
            logger.error("WeatherKit request failed: \(error, privacy: .public)")
            return nil
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
