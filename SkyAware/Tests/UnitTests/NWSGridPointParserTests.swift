import Testing
@testable import SkyAware
import Foundation

@Suite("NWSGridPointParser")
struct NWSGridPointParserTests {
    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    @Test
    func decodesValidGridPoint() throws {
        let json = """
        {
          "id": "https://api.weather.gov/points/35.0,-97.0",
          "type": "Feature",
          "geometry": null,
          "properties": {
            "@context": ["https://geojson.org/geojson-ld/geojson-context.jsonld"],
            "@id": "https://api.weather.gov/points/35.0,-97.0",
            "@type": "wx:Point",
            "cwa": "OUN",
            "forecastOffice": "https://api.weather.gov/offices/OUN",
            "gridId": "OUN",
            "gridX": 34,
            "gridY": 74,
            "forecast": "https://api.weather.gov/gridpoints/OUN/34,74/forecast",
            "forecastHourly": "https://api.weather.gov/gridpoints/OUN/34,74/forecast/hourly",
            "forecastGridData": "https://api.weather.gov/gridpoints/OUN/34,74",
            "observationStations": "https://api.weather.gov/gridpoints/OUN/34,74/stations",
            "relativeLocation": {
              "type": "Feature",
              "geometry": null,
              "properties": {
                "city": "Oklahoma City",
                "state": "OK",
                "distance": { "value": 10.0, "unitCode": "wmoUnit:m" },
                "bearing": { "value": 180.0, "unitCode": "wmoUnit:degree_(angle)" }
              }
            },
            "forecastZone": "https://api.weather.gov/zones/forecast/OKZ025",
            "county": "https://api.weather.gov/zones/county/OKC109",
            "fireWeatherZone": "https://api.weather.gov/zones/fire/OKZ025",
            "timeZone": "America/Chicago",
            "radarStation": "KTLX"
          }
        }
        """
        
        let result = NWSGridPointParser.decode(from: data(json))
        let point = try #require(result)
        #expect(point.type == "Feature")
        #expect(point.properties.gridId == "OUN")
        #expect(point.properties.gridX == 34)
        #expect(point.properties.gridY == 74)
        #expect(point.properties.relativeLocation?.properties.city == "Oklahoma City")
    }

    @Test
    func returnsNilWhenRequiredKeyMissing() {
        let json = """
        {
          "id": "https://api.weather.gov/points/35.0,-97.0",
          "type": "Feature",
          "properties": {
            "gridX": 34,
            "gridY": 74
          }
        }
        """
        
        let result = NWSGridPointParser.decode(from: data(json))
        #expect(result == nil)
    }

    @Test
    func returnsNilWhenTypeMismatch() {
        let json = """
        {
          "id": "https://api.weather.gov/points/35.0,-97.0",
          "type": "Feature",
          "properties": {
            "gridId": "OUN",
            "gridX": "34",
            "gridY": 74
          }
        }
        """
        
        let result = NWSGridPointParser.decode(from: data(json))
        #expect(result == nil)
    }

    @Test
    func returnsNilWhenValueIsNull() {
        let json = """
        {
          "id": "https://api.weather.gov/points/35.0,-97.0",
          "type": "Feature",
          "properties": {
            "gridId": null,
            "gridX": 34,
            "gridY": 74
          }
        }
        """
        
        let result = NWSGridPointParser.decode(from: data(json))
        #expect(result == nil)
    }

    @Test
    func returnsNilForCorruptedData() {
        let json = "{ not-valid-json }"
        let result = NWSGridPointParser.decode(from: data(json))
        #expect(result == nil)
    }
}
