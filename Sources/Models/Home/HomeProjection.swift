//
//  HomeProjection.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftData

struct HomeProjectionWeatherPayload: Sendable, Codable, Equatable {
    let temperatureFahrenheit: Double
    let symbolName: String
    let conditionText: String
    let asOf: Date
    let dewPointFahrenheit: Double
    let humidity: Double
    let windSpeedMilesPerHour: Double
    let windGustMilesPerHour: Double?
    let windDirection: String
    let pressureInchesOfMercury: Double
    let pressureTrend: String

    init(summary: SummaryWeather) {
        temperatureFahrenheit = summary.temperature.converted(to: .fahrenheit).value
        symbolName = summary.symbolName
        conditionText = summary.conditionText
        asOf = summary.asOf
        dewPointFahrenheit = summary.dewPoint.converted(to: .fahrenheit).value
        humidity = summary.humidity
        windSpeedMilesPerHour = summary.windSpeed.converted(to: .milesPerHour).value
        windGustMilesPerHour = summary.windGust?.converted(to: .milesPerHour).value
        windDirection = summary.windDirection
        pressureInchesOfMercury = summary.pressure.converted(to: .inchesOfMercury).value
        pressureTrend = summary.pressureTrend
    }

    var summaryWeather: SummaryWeather {
        SummaryWeather(
            temperature: .init(value: temperatureFahrenheit, unit: .fahrenheit),
            symbolName: symbolName,
            conditionText: conditionText,
            asOf: asOf,
            dewPoint: .init(value: dewPointFahrenheit, unit: .fahrenheit),
            humidity: humidity,
            windSpeed: .init(value: windSpeedMilesPerHour, unit: .milesPerHour),
            windGust: windGustMilesPerHour.map { .init(value: $0, unit: .milesPerHour) },
            windDirection: windDirection,
            pressure: .init(value: pressureInchesOfMercury, unit: .inchesOfMercury),
            pressureTrend: pressureTrend
        )
    }
}

struct HomeProjectionRecord: Sendable, Equatable {
    let id: UUID
    let projectionKey: String
    let latitude: Double
    let longitude: Double
    let h3Cell: Int64
    let countyCode: String
    let forecastZone: String?
    let fireZone: String
    let placemarkSummary: String?
    let timeZoneId: String?
    let locationTimestamp: Date
    let createdAt: Date
    let updatedAt: Date
    let lastViewedAt: Date?
    let weather: SummaryWeather?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let activeAlerts: [WatchRowDTO]
    let activeMesos: [MdDTO]
    let lastHotAlertsLoadAt: Date?
    let lastSlowProductsLoadAt: Date?
    let lastWeatherLoadAt: Date?
}

@Model
final class HomeProjection {
    var id: UUID
    var projectionKey: String

    var latitude: Double
    var longitude: Double
    var h3Cell: Int64
    var countyCode: String
    var forecastZone: String?
    var fireZone: String
    var placemarkSummary: String?
    var timeZoneId: String?

    var locationTimestamp: Date
    var createdAt: Date
    var updatedAt: Date
    var lastViewedAt: Date?

    var weatherPayload: HomeProjectionWeatherPayload?
    var stormRisk: StormRiskLevel?
    var severeRisk: SevereWeatherThreat?
    var fireRisk: FireRiskLevel?
    var activeAlerts: [WatchRowDTO]
    var activeMesos: [MdDTO]

    var lastHotAlertsLoadAt: Date?
    var lastSlowProductsLoadAt: Date?
    var lastWeatherLoadAt: Date?

    init(
        context: LocationContext,
        createdAt: Date = .now,
        lastViewedAt: Date? = nil
    ) {
        id = UUID()
        projectionKey = Self.projectionKey(for: context)
        latitude = context.snapshot.coordinates.latitude
        longitude = context.snapshot.coordinates.longitude
        h3Cell = context.h3Cell
        countyCode = context.grid.countyCode ?? ""
        forecastZone = context.grid.forecastZone
        fireZone = context.grid.fireZone ?? ""
        placemarkSummary = context.snapshot.placemarkSummary
        timeZoneId = context.grid.timeZoneId
        locationTimestamp = context.snapshot.timestamp
        self.createdAt = createdAt
        updatedAt = createdAt
        self.lastViewedAt = lastViewedAt
        weatherPayload = nil
        stormRisk = nil
        severeRisk = nil
        fireRisk = nil
        activeAlerts = []
        activeMesos = []
        lastHotAlertsLoadAt = nil
        lastSlowProductsLoadAt = nil
        lastWeatherLoadAt = nil
    }
}

extension HomeProjection {
    static func projectionKey(for context: LocationContext) -> String {
        let components = [
            "h3:\(context.h3Cell)",
            "county:\(normalizedKeyComponent(context.grid.countyCode))",
            "forecast:\(normalizedKeyComponent(context.grid.forecastZone))",
            "fire:\(normalizedKeyComponent(context.grid.fireZone))"
        ]
        return components.joined(separator: "|")
    }

    var record: HomeProjectionRecord {
        HomeProjectionRecord(
            id: id,
            projectionKey: projectionKey,
            latitude: latitude,
            longitude: longitude,
            h3Cell: h3Cell,
            countyCode: countyCode,
            forecastZone: forecastZone,
            fireZone: fireZone,
            placemarkSummary: placemarkSummary,
            timeZoneId: timeZoneId,
            locationTimestamp: locationTimestamp,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastViewedAt: lastViewedAt,
            weather: weatherPayload?.summaryWeather,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            activeAlerts: activeAlerts,
            activeMesos: activeMesos,
            lastHotAlertsLoadAt: lastHotAlertsLoadAt,
            lastSlowProductsLoadAt: lastSlowProductsLoadAt,
            lastWeatherLoadAt: lastWeatherLoadAt
        )
    }

    func updateLocationContext(_ context: LocationContext, touchedAt: Date, viewedAt: Date? = nil) {
        latitude = context.snapshot.coordinates.latitude
        longitude = context.snapshot.coordinates.longitude
        h3Cell = context.h3Cell
        countyCode = context.grid.countyCode ?? ""
        forecastZone = context.grid.forecastZone
        fireZone = context.grid.fireZone ?? ""
        placemarkSummary = context.snapshot.placemarkSummary
        timeZoneId = context.grid.timeZoneId
        locationTimestamp = context.snapshot.timestamp
        updatedAt = touchedAt
        if let viewedAt {
            lastViewedAt = viewedAt
        }
    }

    private static func normalizedKeyComponent(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return "_"
        }
        return trimmed.uppercased()
    }
}
