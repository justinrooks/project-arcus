//
//  SummaryWeather.swift
//  SkyAware
//
//  Created by Justin Rooks on 2/18/26.
//

import Foundation

struct SummaryWeather: Sendable, Equatable {
    let temperature: Measurement<UnitTemperature>
    let symbolName: String
    let conditionText: String
    let asOf: Date
    let dewPoint: Measurement<UnitTemperature>
    let humidity: Double
    let windSpeed:Measurement<UnitSpeed>
    let windGust: Measurement<UnitSpeed>?
    let windDirection: String
    let pressure: Measurement<UnitPressure>
    let pressureTrend: String
    let visibility: Measurement<UnitLength>?

    init(
        temperature: Measurement<UnitTemperature>,
        symbolName: String,
        conditionText: String,
        asOf: Date,
        dewPoint: Measurement<UnitTemperature>,
        humidity: Double,
        windSpeed: Measurement<UnitSpeed>,
        windGust: Measurement<UnitSpeed>?,
        windDirection: String,
        pressure: Measurement<UnitPressure>,
        pressureTrend: String,
        visibility: Measurement<UnitLength>? = nil
    ) {
        self.temperature = temperature
        self.symbolName = symbolName
        self.conditionText = conditionText
        self.asOf = asOf
        self.dewPoint = dewPoint
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windGust = windGust
        self.windDirection = windDirection
        self.pressure = pressure
        self.pressureTrend = pressureTrend
        self.visibility = visibility
    }
}
