#if canImport(Testing)
import Testing
@testable import SkyAware

@Suite("Atmospheric conditions presentation")
struct AtmosphericConditionsDescriptorTests {
    @Test("AQI at or below 100 is hidden")
    func aqiAtOrBelowOneHundredIsHidden() {
        #expect(AirQualityPresentation(aqi: 100, primaryPollutant: nil) == nil)
    }

    @Test("AQI override shows valid values below the severe-weather threshold")
    func aqiOverrideShowsValidLowerValues() {
        let presentation = AirQualityPresentation(aqi: 100, primaryPollutant: nil, alwaysShow: true)

        #expect(presentation?.shortCategory == "Moderate")
        #expect(presentation?.semanticAccent == .moderate)
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

    @Test("hidden AQI preserves the original three-metric rail")
    func hiddenAQIPreservesThreeMetricRail() {
        let model = AtmosphericConditionsDisplayModel(weather: sampleWeather, airQuality: nil)

        #expect(model.secondaryMetrics.map(\.kind) == [.humidity, .wind, .pressure])
        #expect(AtmosphericMetricRailLayout.compactColumnCount(for: model.secondaryMetrics.count) == 3)
    }

    @Test("AQI rail wraps to two readable columns")
    func aqiRailWrapsToTwoColumns() {
        #expect(AtmosphericMetricRailLayout.compactColumnCount(for: 4) == 2)
    }
    @Test("dew points below 50 are dry air")
    func belowFiftyIsDryAir() {
        #expect(DewPointDescriptor.text(for: 49.9) == "Dry air in place")
    }

    @Test("dew points from 50 to 59 are comfortable moisture")
    func fiftyToFiftyNineIsComfortableMoisture() {
        #expect(DewPointDescriptor.text(for: 50.0) == "Comfortable moisture")
        #expect(DewPointDescriptor.text(for: 59.9) == "Comfortable moisture")
    }

    @Test("dew points from 60 to 64 are moisture increasing")
    func sixtyToSixtyFourIsMoistureIncreasing() {
        #expect(DewPointDescriptor.text(for: 60.0) == "Moisture increasing")
        #expect(DewPointDescriptor.text(for: 64.9) == "Moisture increasing")
    }

    @Test("dew points from 65 to 69 are moist air may support storms")
    func sixtyFiveToSixtyNineSupportsStorms() {
        #expect(DewPointDescriptor.text(for: 65.0) == "Moist air may support storms")
        #expect(DewPointDescriptor.text(for: 69.9) == "Moist air may support storms")
    }

    @Test("dew points 70 and above are very moist")
    func seventyAndAboveIsVeryMoist() {
        #expect(DewPointDescriptor.text(for: 70.0) == "Very moist air in place")
        #expect(DewPointDescriptor.text(for: 74.2) == "Very moist air in place")
    }

    @Test("missing dew point returns unavailable text")
    func missingValueReturnsUnavailableText() {
        #expect(DewPointDescriptor.text(for: nil) == "Dew point unavailable")
    }

    private var sampleWeather: SummaryWeather {
        SummaryWeather(
            temperature: .init(value: 72, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: .now,
            dewPoint: .init(value: 48, unit: .fahrenheit),
            humidity: 0.4,
            windSpeed: .init(value: 8, unit: .milesPerHour),
            windGust: nil,
            windDirection: "N",
            pressure: .init(value: 30, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
    }
}
#endif
