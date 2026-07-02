import Foundation
import Testing
@testable import SkyAware

private actor StormSetupMockHTTPClientState {
    var requests: [(method: String, url: URL, headers: [String: String])] = []

    func record(method: String, url: URL, headers: [String: String]) {
        requests.append((method: method, url: url, headers: headers))
    }

    func firstRequest() -> (method: String, url: URL, headers: [String: String])? {
        requests.first
    }
}

private final class StormSetupMockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = StormSetupMockHTTPClientState()
    private let response: HTTPResponse
    private let error: Error?

    init(response: HTTPResponse, error: Error? = nil) {
        self.response = response
        self.error = error
    }

    func get(_ url: URL, headers: [String : String]) async throws -> HTTPResponse {
        await state.record(method: "GET", url: url, headers: headers)

        if let error {
            throw error
        }
        return response
    }

    func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
        await state.record(method: "POST", url: url, headers: headers)

        if let error {
            throw error
        }
        return response
    }

    func clearCache() {}

    func firstRequest() async -> (method: String, url: URL, headers: [String: String])? {
        await state.firstRequest()
    }
}

@Suite("StormSetupHTTPClient")
struct StormSetupHTTPClientTests {
    @Test("request construction uses canonical H3 query and Arcus headers")
    func requestConstructionUsesCanonicalH3QueryAndHeaders() async throws {
        let payload = stormSetupPayload()
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        let request = try #require(await http.firstRequest())
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))

        #expect(request.method == "GET")
        #expect(components.scheme == "https")
        #expect(components.host == "api.skyaware.app")
        #expect(components.path == "/api/v1/storm-setup/current")
        #expect(components.queryItems?.first(where: { $0.name == "h3" })?.value == "613160066540896255")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
    }

    @Test("successful decoding preserves the assessment summary prose")
    func successfulDecodingPreservesAssessmentSummaryProse() async throws {
        let payload = stormSetupPayload()
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        let dto = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        #expect(dto.h3Cell == 613_160_066_540_896_255)
        #expect(dto.freshness.forecastHour == 6)
        #expect(dto.source.product == "Storm Setup")
        #expect(dto.raw.mlcapeJkg == 1850)
        #expect(dto.surfaceHeightMslM == 1340)
        #expect(dto.assessment.summary == "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.")
    }

    @Test("200 without a body maps to ArcusError.missingData")
    func missingBodyMapsToMissingData() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: nil)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        do {
            _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.missingData")
        } catch let error as ArcusError {
            #expect(error == .missingData)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("malformed payload maps to ArcusError.parsingError")
    func malformedPayloadMapsToParsingError() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: Data(#"{"h3Cell":1}"#.utf8))
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        do {
            _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.parsingError")
        } catch let error as ArcusError {
            #expect(error == .parsingError)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("429 status maps to ArcusError.rateLimited")
    func rateLimitedMapsToRateLimited() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 429, headers: ["Retry-After": "30"], data: Data("down".utf8))
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        do {
            _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.rateLimited")
        } catch let error as ArcusError {
            #expect(error == .rateLimited(retryAfterSeconds: 30))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("503 status maps to ArcusError.serviceUnavailable")
    func serviceUnavailableMapsToServiceUnavailable() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 503, headers: ["Retry-After": "45"], data: Data("down".utf8))
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        do {
            _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.serviceUnavailable")
        } catch let error as ArcusError {
            #expect(error == .serviceUnavailable(retryAfterSeconds: 45))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("500 status maps to ArcusError.networkError")
    func serverErrorMapsToNetworkError() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 500, headers: [:], data: Data("oops".utf8))
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        do {
            _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.networkError(status: 500)")
        } catch let error as ArcusError {
            #expect(error == .networkError(status: 500))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("cancellation passes through unchanged")
    func cancellationPassesThroughUnchanged() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: stormSetupPayload()),
            error: CancellationError()
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        do {
            _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected CancellationError")
        } catch is CancellationError {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("cache-backed responses decode without reachability dependencies")
    func cacheBackedResponsesDecodeWithoutReachabilityDependencies() async throws {
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: stormSetupPayload(), source: .localCache)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        let dto = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        #expect(dto.assessment.confidence == "high")
        #expect(dto.assessment.summary == "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.")
    }
}

private func stormSetupPayload() -> Data {
    Data(#"""
    {
      "h3Cell": 613160066540896255,
      "freshness": {
        "isStale": false,
        "isDegraded": false,
        "modelRunTime": "2026-06-01T18:00:00Z",
        "sourceValidTime": "2026-06-01T21:00:00Z",
        "forecastHour": 6,
        "fetchedAt": "2026-06-01T21:03:00Z",
        "expiresAt": "2026-06-01T22:00:00Z"
      },
      "source": {
        "model": "HRRR",
        "product": "Storm Setup",
        "domain": "severe",
        "fieldSetVersion": "1",
        "sourceKind": "production",
        "runTime": "2026-06-01T18:00:00Z",
        "validTime": "2026-06-01T21:00:00Z",
        "forecastHour": 6,
        "bbox": {
          "toplat": 41.5,
          "leftlon": -104.3,
          "rightlon": -96.2,
          "bottomlat": 36.8
        },
        "primaryDownloadURL": "https://example.invalid/storm-setup"
      },
      "raw": {
        "mlcapeJkg": 1850,
        "mucapeJkg": 2200.5,
        "sbcapeJkg": 1700,
        "mlcinJkg": -42,
        "srh01kmM2s2": 125.5,
        "srh03kmM2s2": 175,
        "shear06kmKt": 42,
        "mllclM": 980,
        "tempDewPtDeltaF": 4.5,
        "threeCapeJkg": 95
      },
      "assessment": {
        "overall": "strong",
        "summary": "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
        "confidence": "high"
      },
      "surfaceHeightMslM": 1340
    }
    """#.utf8)
}
