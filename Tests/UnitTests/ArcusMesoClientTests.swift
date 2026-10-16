import ArcusCore
import Foundation
import Testing
@testable import SkyAware

private actor ArcusMesoHTTPState {
    var request: (url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy)?

    func record(url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy) {
        request = (url, headers, fallbackPolicy)
    }
}

private actor ArcusMesoReachabilityRecorder: ArcusSignalReachabilityReporting {
    private(set) var lastState: State?

    enum State { case reachable, unavailable }

    func markReachable() async { lastState = .reachable }
    func markUnavailable() async { lastState = .unavailable }
}

private final class ArcusMesoMockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = ArcusMesoHTTPState()
    private let response: HTTPResponse

    init(response: HTTPResponse) {
        self.response = response
    }

    func get(_ url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy) async throws -> HTTPResponse {
        await state.record(url: url, headers: headers, fallbackPolicy: fallbackPolicy)
        return response
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        fatalError("Arcus meso reads must use GET")
    }

    func clearCache() {}

    func recordedRequest() async -> (url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy)? {
        await state.request
    }
}

@Suite("ArcusMesoClient")
struct ArcusMesoClientTests {
    @Test("all-active and H3 reads use the shared endpoint and Arcus cache conventions")
    func collectionRequestsUseExpectedQueryAndCachePolicy() async throws {
        let http = ArcusMesoMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: Data("[]".utf8)))
        let client = ArcusMesoHTTPClient(baseURL: URL(string: "https://arcus.example.com")!, http: http)

        _ = try await client.fetchActiveMesos(h3Cell: nil)
        let allRequest = try #require(await http.recordedRequest())
        let allComponents = try #require(URLComponents(url: allRequest.url, resolvingAgainstBaseURL: false))
        #expect(allComponents.path == "/v1/mesos")
        #expect(allComponents.queryItems == nil)
        #expect(allRequest.headers["Accept"] == "application/json")
        #expect(allRequest.fallbackPolicy == .maximumAge(2 * 60))

        _ = try await client.fetchActiveMesos(h3Cell: 613_160_066_540_896_255)
        let h3Request = try #require(await http.recordedRequest())
        let h3Components = try #require(URLComponents(url: h3Request.url, resolvingAgainstBaseURL: false))
        #expect(h3Components.queryItems == [URLQueryItem(name: "h3", value: "613160066540896255")])
    }

    @Test("provider decodes empty and full shared meso payloads including geometry")
    func providerDecodesEmptyAndFullPayload() async throws {
        let emptyClient = ArcusMesoProvider(client: StubArcusMesoClient(activeData: Data("[]".utf8)))
        let emptyResult = try await emptyClient.getActiveMesos()
        #expect(emptyResult.value.isEmpty)
        #expect(emptyResult.source == .live)

        let issued = try #require(ISO8601DateFormatter().date(from: "2035-06-01T18:00:00Z"))
        let payload = try encodedMesoPayload(issued: issued)
        let json = try #require(JSONSerialization.jsonObject(with: payload) as? [[String: Any]])
        let firstJSON = try #require(json.first)
        #expect(firstJSON["issued"] as? Double == issued.timeIntervalSinceReferenceDate)

        let provider = ArcusMesoProvider(client: StubArcusMesoClient(activeData: payload))
        let result = try await provider.getActiveMesos()
        let meso = try #require(result.value.first)
        #expect(result.source == .live)
        #expect(meso.productID == "SPC-MD-2035-1234")
        #expect(meso.issueYear == 2035)
        #expect(meso.number == 1234)
        #expect(meso.title == "Mesoscale Discussion 1234")
        #expect(meso.sourceURL == URL(string: "https://www.spc.noaa.gov/products/md/2035/md1234.html"))
        #expect(meso.issued == issued)
        #expect(meso.validStart == issued)
        #expect(meso.validEnd == issued.addingTimeInterval(3 * 60 * 60))
        #expect(meso.areasAffected == "Eastern Colorado")
        #expect(meso.summary == "Severe storms possible.")
        #expect(meso.concerning == "Severe potential")
        #expect(meso.watchProbability == 40)
        #expect(meso.watchProbabilityText == "40%")
        #expect(meso.threats?.peakWindMPH == 70)
        #expect(meso.threats?.hailRangeInches == 1.5)
        #expect(meso.threats?.tornadoStrength == "EF2")
        #expect(meso.coordinates == [MesoscaleDiscussionCoordinate(latitude: 39.5, longitude: -104.8)])
    }

    @Test("provider rejects malformed payload and maps targeted not-found to nil")
    func providerHandlesMalformedAndNotFoundResponses() async throws {
        let malformedProvider = ArcusMesoProvider(client: StubArcusMesoClient(activeData: Data("not-json".utf8)))
        await #expect(throws: ArcusError.parsingError) {
            try await malformedProvider.getActiveMesos()
        }

        let notFoundProvider = ArcusMesoProvider(client: StubArcusMesoClient(mesoError: ArcusError.networkError(status: 404)))
        #expect(try await notFoundProvider.getMeso(productID: "SPC-MD-2026-1234") == nil)
    }

    @Test("targeted read requests the stable product identifier and accepts revalidated cache data")
    func targetedRequestUsesProductIDAndRevalidatedResponse() async throws {
        let issued = try #require(ISO8601DateFormatter().date(from: "2035-06-01T18:00:00Z"))
        let payload = try encodedMesoPayload(issued: issued)
        let http = ArcusMesoMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let reachability = ArcusMesoReachabilityRecorder()
        let client = ArcusMesoHTTPClient(
            baseURL: URL(string: "https://arcus.example.com")!,
            http: http,
            reachabilityReporter: reachability
        )

        let result = try #require(
            await ArcusMesoProvider(client: client).getMeso(productID: "SPC-MD-2035-1234")
        )

        let request = try #require(await http.recordedRequest())
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == [URLQueryItem(name: "id", value: "SPC-MD-2035-1234")])
        #expect(request.fallbackPolicy == .maximumAge(2 * 60))
        #expect(result.source == .cacheRevalidated304)
        #expect(result.value.productID == "SPC-MD-2035-1234")
        #expect(result.value.coordinates.count == 1)
        #expect(await reachability.lastState == .reachable)
    }

    @Test("cache fallback marks Arcus unavailable")
    func cacheFallbackMarksArcusUnavailable() async throws {
        let http = ArcusMesoMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: Data("[]".utf8), source: .cacheFallback)
        )
        let reachability = ArcusMesoReachabilityRecorder()
        let client = ArcusMesoHTTPClient(
            baseURL: URL(string: "https://arcus.example.com")!,
            http: http,
            reachabilityReporter: reachability
        )

        let result = try await ArcusMesoProvider(client: client).getActiveMesos()

        #expect(await reachability.lastState == .unavailable)
        #expect(result.value.isEmpty)
        #expect(result.source == .cacheFallback)
    }
}

private struct StubArcusMesoClient: ArcusMesoClient {
    let activeResponse: HTTPResponse
    var mesoError: ArcusError?

    init(activeData: Data = Data("[]".utf8), mesoError: ArcusError? = nil) {
        self.activeResponse = HTTPResponse(status: 200, headers: [:], data: activeData)
        self.mesoError = mesoError
    }

    func fetchActiveMesos(h3Cell: Int64?) async throws -> HTTPResponse { activeResponse }

    func fetchMeso(productID: String) async throws -> HTTPResponse {
        if let mesoError { throw mesoError }
        return activeResponse
    }
}

private func encodedMesoPayload(issued: Date) throws -> Data {
    let payload = MesoscaleDiscussionPayload(
        number: 1234,
        title: "Mesoscale Discussion 1234",
        sourceURL: URL(string: "https://www.spc.noaa.gov/products/md/2035/md1234.html")!,
        issued: issued,
        validStart: issued,
        validEnd: issued.addingTimeInterval(3 * 60 * 60),
        areasAffected: "Eastern Colorado",
        summary: "Severe storms possible.",
        concerning: "Severe potential",
        watchProbability: 40,
        watchProbabilityText: "40%",
        threats: MesoscaleDiscussionThreats(peakWindMPH: 70, hailRangeInches: 1.5, tornadoStrength: "EF2"),
        coordinates: [MesoscaleDiscussionCoordinate(latitude: 39.5, longitude: -104.8)]
    )
    return try JSONEncoder().encode([payload])
}
