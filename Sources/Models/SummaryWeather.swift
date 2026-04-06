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
}
