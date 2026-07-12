#if canImport(Testing)
import ArcusCore
import Foundation
import Testing
@testable import SkyAware

@Suite("AirQualityHTTPClient")
struct AirQualityHTTPClientTests {
    @Test("decodes the normalized Arcus AQI contract")
    func decodesCurrentResponse() async throws {
        let http = AirQualityStubHTTPClient(data: Data("""
        {"aqi":121,"category":{"identifier":3,"name":"Unhealthy for Sensitive Groups"},"primaryPollutant":"PM2.5","observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}
        """.utf8))
        let client = AirQualityHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        let response = try await client.fetchCurrentAirQuality(h3Cell: 613_160_066_540_896_255)

        #expect(response?.aqi == 121)
        #expect(response?.category?.identifier == 3)
        #expect(response?.primaryPollutant == "PM2.5")
        #expect(http.url?.path == "/api/v1/air-quality/current")
        #expect(URLComponents(url: try #require(http.url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "613160066540896255")
    }
}

private final class AirQualityStubHTTPClient: HTTPClient, @unchecked Sendable {
    let data: Data
    private(set) var url: URL?

    init(data: Data) { self.data = data }

    func get(_ url: URL, headers: [String: String]) async throws -> HTTPResponse {
        self.url = url
        return HTTPResponse(status: 200, headers: [:], data: data, source: .network)
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        fatalError("Unexpected request")
    }

    func clearCache() {}
}
#endif
