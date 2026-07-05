import Foundation
import Testing
@testable import SkyAware

private actor StormSetupProfileAnalysisMockHTTPClientState {
    var requests: [(method: String, url: URL, headers: [String: String])] = []

    func record(method: String, url: URL, headers: [String: String]) {
        requests.append((method: method, url: url, headers: headers))
    }

    func firstRequest() -> (method: String, url: URL, headers: [String: String])? {
        requests.first
    }
}

private final class StormSetupProfileAnalysisMockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = StormSetupProfileAnalysisMockHTTPClientState()
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

private actor CancellationGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private final class CancellationAwareHTTPClient: HTTPClient, @unchecked Sendable {
    private let gate: CancellationGate
    private let response: HTTPResponse

    init(gate: CancellationGate, response: HTTPResponse) {
        self.gate = gate
        self.response = response
    }

    func get(_ url: URL, headers: [String : String]) async throws -> HTTPResponse {
        await gate.wait()
        return response
    }

    func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
        await gate.wait()
        return response
    }

    func clearCache() {}
}

@Suite("StormSetupProfileAnalysisHTTPClient")
struct StormSetupProfileAnalysisHTTPClientTests {
    @Test("request construction uses the dev profile-analysis route, GET, canonical decimal H3, and Arcus headers")
    func requestConstructionUsesDevProfileAnalysisRoute() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: StormSetupProfileAnalysisTestFixtures.richJSON.data(using: .utf8), source: .cacheRevalidated304)
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        _ = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)

        let request = try #require(await http.firstRequest())
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))

        #expect(request.method == "GET")
        #expect(components.scheme == "https")
        #expect(components.host == "api.skyaware.app")
        #expect(components.path == ArcusSignalConfiguration.stormSetupProfileAnalysisPath)
        #expect(components.queryItems?.first(where: { $0.name == "h3" })?.value == "613160066540896255")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
    }

    @Test("rich response decodes the SS-10 wrapper DTO")
    func richResponseDecodesTheWrapperDTO() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(
                status: 200,
                headers: [:],
                data: StormSetupProfileAnalysisTestFixtures.richJSON.data(using: .utf8)
            )
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        let dto = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)

        #expect(dto.request?.runTime == iso("2026-06-01T18:00:00Z"))
        #expect(dto.request?.validTime == iso("2026-06-01T21:00:00Z"))
        #expect(dto.request?.forecastHour == 3)
        #expect(dto.response.mlcape == 1_850)
        #expect(dto.response.stormMotion?.bunkersRight?.directionTowardDeg == 215)
    }

    @Test("sparse response decodes optional request and response fields")
    func sparseResponseDecodesOptionalFields() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(
                status: 304,
                headers: [:],
                data: StormSetupProfileAnalysisTestFixtures.sparseJSON.data(using: .utf8),
                source: .localCache
            )
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        let dto = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)

        #expect(dto.request?.runTime == nil)
        #expect(dto.request?.validTime == nil)
        #expect(dto.request?.forecastHour == nil)
        #expect(dto.response.effectiveLayer?.status == "notFound")
        #expect(dto.response.stormMotion == nil)
        #expect(dto.response.quality == nil)
    }

    @Test("cached HTTP response source still decodes successfully")
    func cachedResponseSourceDecodesSuccessfully() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(
                status: 200,
                headers: [:],
                data: StormSetupProfileAnalysisTestFixtures.richJSON.data(using: .utf8),
                source: .localCache
            )
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        let dto = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)

        #expect(dto.request?.forecastHour == 3)
        #expect(dto.response.mucape == 2_200.5)
    }

    @Test("missing body maps to ArcusError.missingData")
    func missingBodyMapsToMissingData() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: nil)
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        do {
            _ = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.missingData")
        } catch let error as ArcusError {
            #expect(error == .missingData)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("malformed JSON maps to ArcusError.parsingError")
    func malformedJSONMapsToParsingError() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: Data(#"{"request":1}"#.utf8))
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        do {
            _ = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.parsingError")
        } catch let error as ArcusError {
            #expect(error == .parsingError)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("429 status maps to ArcusError.rateLimited with retry-after")
    func status429MapsToRateLimited() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(status: 429, headers: ["Retry-After": "30"], data: Data("down".utf8))
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        do {
            _ = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.rateLimited")
        } catch let error as ArcusError {
            #expect(error == .rateLimited(retryAfterSeconds: 30))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("503 status maps to ArcusError.serviceUnavailable with retry-after")
    func status503MapsToServiceUnavailable() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(status: 503, headers: ["Retry-After": "45"], data: Data("down".utf8))
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        do {
            _ = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.serviceUnavailable")
        } catch let error as ArcusError {
            #expect(error == .serviceUnavailable(retryAfterSeconds: 45))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("generic failure status maps to ArcusError.networkError")
    func genericFailureStatusMapsToNetworkError() async throws {
        let http = StormSetupProfileAnalysisMockHTTPClient(
            response: HTTPResponse(status: 500, headers: [:], data: Data("oops".utf8))
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        do {
            _ = try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
            #expect(Bool(false), "Expected ArcusError.networkError(status: 500)")
        } catch let error as ArcusError {
            #expect(error == .networkError(status: 500))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("cancellation before the HTTP request is preserved")
    func cancellationBeforeTheHTTPRequestIsPreserved() async throws {
        let gate = CancellationGate()
        let http = CancellationAwareHTTPClient(
            gate: gate,
            response: HTTPResponse(status: 200, headers: [:], data: StormSetupProfileAnalysisTestFixtures.richJSON.data(using: .utf8))
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        let task = Task {
            try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
        }

        task.cancel()
        await gate.release()

        do {
            _ = try await task.value
            #expect(Bool(false), "Expected CancellationError")
        } catch is CancellationError {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("cancellation after the HTTP request is preserved")
    func cancellationAfterTheHTTPRequestIsPreserved() async throws {
        let gate = CancellationGate()
        let http = CancellationAwareHTTPClient(
            gate: gate,
            response: HTTPResponse(status: 200, headers: [:], data: StormSetupProfileAnalysisTestFixtures.richJSON.data(using: .utf8))
        )
        let client = StormSetupProfileAnalysisHTTPClient(
            baseURL: URL(string: "https://api.skyaware.app")!,
            http: http
        )

        let task = Task {
            try await client.fetchProfileAnalysis(h3Cell: 613_160_066_540_896_255)
        }

        await Task.yield()
        task.cancel()
        await gate.release()

        do {
            _ = try await task.value
            #expect(Bool(false), "Expected CancellationError")
        } catch is CancellationError {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
}

private func iso(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
