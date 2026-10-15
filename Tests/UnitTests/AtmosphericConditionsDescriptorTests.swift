#if canImport(Testing)
import ArcusCore
import Foundation
import Testing
import SwiftUI
import WeatherKit
@testable import SkyAware

@Suite("Atmospheric conditions presentation")
struct AtmosphericConditionsDescriptorTests {
    @Test("Good and Moderate AQI remain visible in the peer metric")
    func goodAndModerateAQIRemainVisible() {
        let good = AirQualityPresentation(aqi: 42, primaryPollutant: nil)
        let moderate = AirQualityPresentation(aqi: 100, primaryPollutant: nil)

        #expect(good?.value == "42")
        #expect(good?.shortCategory == "Good")
        #expect(good?.semanticAccent == .good)
        #expect(moderate?.value == "100")
        #expect(moderate?.shortCategory == "Moderate")
        #expect(moderate?.semanticAccent == .moderate)
        #expect(moderate?.accessibilityValue == "Air quality index 100, moderate.")
    }

    @Test("AQI 101 through 150 uses USG")
    func aqiUSGRange() {
        #expect(AirQualityPresentation(aqi: 101, primaryPollutant: nil)?.shortCategory == "USG")
        #expect(AirQualityPresentation(aqi: 150, primaryPollutant: nil)?.shortCategory == "USG")
    }

    @Test("AQI 151 through 200 uses Unhealthy")
    func aqiUnhealthyRange() {
        #expect(AirQualityPresentation(aqi: 151, primaryPollutant: nil)?.shortCategory == "Unhealthy")
        #expect(AirQualityPresentation(aqi: 200, primaryPollutant: nil)?.shortCategory == "Unhealthy")
    }

    @Test("AQI 201 uses Very Unhealthy")
    func aqiVeryUnhealthyRange() {
        #expect(AirQualityPresentation(aqi: 201, primaryPollutant: nil)?.shortCategory == "Very Unhealthy")
    }

    @Test("AQI 301 and above uses Hazardous")
    func aqiHazardousRange() {
        #expect(AirQualityPresentation(aqi: 301, primaryPollutant: nil)?.shortCategory == "Hazardous")
    }

    @Test("AQI retains semantic accents for every supported severity")
    func aqiSeverityAccentsRemainSemantic() {
        #expect(AirQualityPresentation(aqi: 40, primaryPollutant: nil)?.semanticAccent == .good)
        #expect(AirQualityPresentation(aqi: 70, primaryPollutant: nil)?.semanticAccent == .moderate)
        #expect(AirQualityPresentation(aqi: 120, primaryPollutant: nil)?.semanticAccent == .caution)
        #expect(AirQualityPresentation(aqi: 175, primaryPollutant: nil)?.semanticAccent == .unhealthy)
        #expect(AirQualityPresentation(aqi: 240, primaryPollutant: nil)?.semanticAccent == .veryUnhealthy)
        #expect(AirQualityPresentation(aqi: 301, primaryPollutant: nil)?.semanticAccent == .hazardous)
    }

    @Test("missing and invalid AQI are hidden")
    func missingAndInvalidAQIAreHidden() {
        #expect(AirQualityPresentation(aqi: nil, primaryPollutant: nil) == nil)
        #expect(AirQualityPresentation(aqi: -1, primaryPollutant: nil) == nil)
    }

    @Test("AQI accessibility uses the full category and optional pollutant")
    func aqiAccessibilityUsesFullCategory() {
        let presentation = AirQualityPresentation(aqi: 112, primaryPollutant: "PM2.5")

        #expect(presentation?.accessibilityValue == "Air quality index 112, unhealthy for sensitive groups. Primary pollutant PM2.5.")
    }

    @Test("atmospheric metrics follow the three plus two row order")
    func atmosphericMetricsFollowThreePlusTwoRowOrder() {
        let model = AtmosphericConditionsDisplayModel(weather: sampleWeather(), airQuality: nil)

        #expect(model.secondaryMetrics.map(\.kind) == [.aqi, .visibility, .pressure, .humidity, .wind])
    }

    @Test("AQI keeps its category detail and semantic accent")
    func visibleAQIHasCategoryDetail() {
        let json = """
        {"aqi":121,"category":{"identifier":3,"name":"Unhealthy for Sensitive Groups"},"primaryPollutant":"PM2.5","observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}
        """
        let airQuality = try? DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(json.utf8)
        )
        let model = AtmosphericConditionsDisplayModel(weather: sampleWeather(), airQuality: airQuality)

        #expect(model.secondaryMetrics.map(\.kind) == [.aqi, .visibility, .pressure, .humidity, .wind])
        #expect(model.secondaryMetrics.first?.detail == "USG")
        #expect(model.secondaryMetrics.first?.iconName == "circle.hexagongrid.fill")
        #expect(model.secondaryMetrics.first?.semanticAccent == .caution)
    }

    @Test("humidity and wind use the current WeatherKit observations without interpretation")
    func humidityAndWindUseCurrentObservations() {
        let weather = sampleWeather(
            windGust: .init(value: 14, unit: .milesPerHour)
        )
        let model = AtmosphericConditionsDisplayModel(weather: weather)

        #expect(model.secondaryMetrics[3].title == "Humidity")
        #expect(model.secondaryMetrics[3].value == "40%")
        #expect(model.secondaryMetrics[3].detail == nil)
        #expect(model.secondaryMetrics[4].title == "Wind")
        #expect(model.secondaryMetrics[4].value == "N · 8 mph")
        #expect(model.secondaryMetrics[4].detail == "Gusts 14 mph")
        #expect(model.secondaryMetrics[4].accessibilityValue == "N · 8 mph, Gusts 14 mph")

        let nonMeaningfulGust = AtmosphericConditionsDisplayModel(
            weather: sampleWeather(windGust: .init(value: 8, unit: .milesPerHour))
        )
        #expect(nonMeaningfulGust.secondaryMetrics[4].detail == nil)
    }

    @Test("weather and AQI availability degrade independently")
    func unavailableWeatherKeepsValidAQI() {
        let json = """
        {"aqi":121,"category":{"identifier":3,"name":"Unhealthy for Sensitive Groups"},"observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}
        """
        let airQuality = try? DecoderFactory.iso8601.decode(AirQualityCurrentResponse.self, from: Data(json.utf8))
        let model = AtmosphericConditionsDisplayModel(weather: nil, airQuality: airQuality)

        #expect(model.secondaryMetrics[0].value == "121")
        #expect(model.secondaryMetrics[1].value == "—")
        #expect(model.secondaryMetrics[2].value == "—")
    }

    @Test("visibility and pressure trends map independently")
    func visibilityAndPressureTrendsAreMappedIndependently() {
        let reduced = AtmosphericConditionsDisplayModel(weather: sampleWeather(), airQuality: nil)
        #expect(reduced.secondaryMetrics[1].value == "8.0 mi")
        #expect(reduced.secondaryMetrics[1].detail == "Reduced")
        #expect(reduced.secondaryMetrics[1].accessibilityValue == "8.0 mi, Reduced")
        #expect(reduced.secondaryMetrics[2].detail == "Steady")
        #expect(reduced.secondaryMetrics[2].accessibilityValue == "30.00 inHg, Steady")

        let clearVisibility = AtmosphericConditionsDisplayModel(
            weather: sampleWeather(visibility: .init(value: 10, unit: .miles)),
            airQuality: nil
        )
        #expect(clearVisibility.secondaryMetrics[1].detail == "Good")

        let risingPressure = AtmosphericConditionsDisplayModel(
            weather: sampleWeather(pressureTrend: "rising"),
            airQuality: nil
        )
        #expect(risingPressure.secondaryMetrics[2].detail == "Rising")
        #expect(risingPressure.secondaryMetrics[2].iconName == "arrow.up")

        let fallingPressure = AtmosphericConditionsDisplayModel(
            weather: sampleWeather(pressureTrend: "falling"),
            airQuality: nil
        )
        #expect(fallingPressure.secondaryMetrics[2].detail == "Falling")
        #expect(fallingPressure.secondaryMetrics[2].iconName == "arrow.down")

        let localizedLegacyTrend = AtmosphericConditionsDisplayModel(
            weather: sampleWeather(pressureTrend: "Hausse"),
            airQuality: nil
        )
        #expect(localizedLegacyTrend.secondaryMetrics[2].detail == "Hausse")
        #expect(localizedLegacyTrend.secondaryMetrics[2].iconName == "barometer")
        #expect(localizedLegacyTrend.secondaryMetrics[2].accessibilityValue == "30.00 inHg, Hausse")
    }

    @Test("WeatherKit pressure trend cases map to stable stored values")
    func weatherKitPressureTrendsMapToStableValues() {
        #expect(WeatherClient.pressureTrendValue(WeatherKit.PressureTrend.rising) == "rising")
        #expect(WeatherClient.pressureTrendValue(WeatherKit.PressureTrend.steady) == "steady")
        #expect(WeatherClient.pressureTrendValue(WeatherKit.PressureTrend.falling) == "falling")
    }

    @Test("missing visibility does not hide pressure or AQI")
    func missingVisibilityKeepsOtherMetrics() {
        let weatherWithoutVisibility = sampleWeather(visibility: nil)
        let airQuality = AirQualityCurrentResponse(
            aqi: 121,
            category: .init(identifier: 3, name: "Unhealthy for Sensitive Groups"),
            primaryPollutant: "PM2.5",
            observedAt: .now,
            sourceIdentifier: "airnow"
        )
        let model = AtmosphericConditionsDisplayModel(
            weather: weatherWithoutVisibility,
            airQuality: airQuality
        )

        #expect(model.secondaryMetrics[0].value == "121")
        #expect(model.secondaryMetrics[1].value == "—")
        #expect(model.secondaryMetrics[2].value == "30.00 inHg")
    }

    @Test("cached weather payload decodes when visibility was not previously stored")
    func cachedWeatherPayloadWithoutVisibilityRemainsReadable() throws {
        let oldPayload = """
        {"temperatureFahrenheit":72,"symbolName":"sun.max.fill","conditionText":"Clear","asOf":200,"dewPointFahrenheit":48,"humidity":0.4,"windSpeedMilesPerHour":8,"windGustMilesPerHour":null,"windDirection":"N","pressureInchesOfMercury":30,"pressureTrend":"steady"}
        """
        let payload = try JSONDecoder().decode(HomeProjectionWeatherPayload.self, from: Data(oldPayload.utf8))

        #expect(payload.summaryWeather.visibility == nil)
    }

    private func sampleWeather(
        visibility: Measurement<UnitLength>? = .init(value: 8, unit: .miles),
        pressureTrend: String = "steady",
        windGust: Measurement<UnitSpeed>? = nil
    ) -> SummaryWeather {
        SummaryWeather(
            temperature: .init(value: 72, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: .now,
            dewPoint: .init(value: 48, unit: .fahrenheit),
            humidity: 0.4,
            windSpeed: .init(value: 8, unit: .milesPerHour),
            windGust: windGust,
            windDirection: "N",
            pressure: .init(value: 30, unit: .inchesOfMercury),
            pressureTrend: pressureTrend,
            visibility: visibility
        )
    }
}

#endif
