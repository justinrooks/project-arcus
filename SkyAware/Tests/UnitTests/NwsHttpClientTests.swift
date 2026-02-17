//
//  NwsHttpClientTests.swift
//  SkyAwareTests
//
//  Created by Justin Rooks on 2/16/26.
//

import Testing
@testable import SkyAware
import Foundation

private actor MockHTTPClientState {
    var requests: [(url: URL, headers: [String: String])] = []

    func record(url: URL, headers: [String: String]) {
        requests.append((url: url, headers: headers))
    }

    func firstRequest() -> (url: URL, headers: [String: String])? {
        requests.first
    }
}

private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = MockHTTPClientState()
    private let response: HTTPResponse
    private let error: Error?

    init(response: HTTPResponse, error: Error? = nil) {
        self.response = response
        self.error = error
    }

    func get(_ url: URL, headers: [String : String]) async throws -> HTTPResponse {
        await state.record(url: url, headers: headers)

        if let error {
            throw error
        }
        return response
    }

    func clearCache() {}

    func firstRequest() async -> (url: URL, headers: [String: String])? {
        await state.firstRequest()
    }
}

@Suite("NwsHttpClient")
struct NwsHttpClientTests {
    @Test("fetchActiveAlerts builds encoded point query and headers")
    func fetchActiveAlerts_buildsPointQuery() async throws {
        let payload = Data("{\"ok\":true}".utf8)
        let http = MockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload))
        let client = NwsHttpClient(http: http)

        let data = try await client.fetchActiveAlertsJsonData(
            for: Coordinate2D(latitude: 39.12349, longitude: -104.98769)
        )

        #expect(data == payload)

        let request = try #require(await http.firstRequest())
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "api.weather.gov")
        #expect(components.path == "/alerts/active")
        #expect(components.queryItems?.first(where: { $0.name == "point" })?.value == "39.1234,-104.9876")
        #expect(request.headers["Accept"] == "application/geo+json")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
    }

    @Test("fetchPointMetadata builds points endpoint path")
    func fetchPointMetadata_buildsPointsPath() async throws {
        let payload = Data("{\"grid\":\"ok\"}".utf8)
        let http = MockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload))
        let client = NwsHttpClient(http: http)

        let data = try await client.fetchPointMetadata(
            for: Coordinate2D(latitude: 35.56789, longitude: -97.01239)
        )

        #expect(data == payload)

        let request = try #require(await http.firstRequest())
        #expect(request.url.path == "/points/35.5678,-97.0123")
    }

    @Test("503 status maps to NwsError.serviceUnavailable")
    func status503_throwsServiceUnavailable() async throws {
        let http = MockHTTPClient(
            response: HTTPResponse(status: 503, headers: ["Retry-After": "30"], data: Data("down".utf8))
        )
        let client = NwsHttpClient(http: http)

        do {
            _ = try await client.fetchPointMetadata(for: Coordinate2D(latitude: 35.1, longitude: -97.1))
            #expect(Bool(false), "Expected NwsError.serviceUnavailable(retryAfterSeconds:)")
        } catch let error as NwsError {
            #expect(error == .serviceUnavailable(retryAfterSeconds: 30))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("429 status maps to NwsError.rateLimited")
    func status429_throwsRateLimited() async throws {
        let http = MockHTTPClient(
            response: HTTPResponse(status: 429, headers: ["Retry-After": "120"], data: nil)
        )
        let client = NwsHttpClient(http: http)

        do {
            _ = try await client.fetchActiveAlertsJsonData(for: Coordinate2D(latitude: 35.0, longitude: -97.0))
            #expect(Bool(false), "Expected NwsError.rateLimited(retryAfterSeconds:)")
        } catch let error as NwsError {
            #expect(error == .rateLimited(retryAfterSeconds: 120))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("empty 2xx body maps to NwsError.missingData")
    func emptyBody_throwsMissingData() async throws {
        let http = MockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: nil))
        let client = NwsHttpClient(http: http)

        do {
            _ = try await client.fetchActiveAlertsJsonData(for: Coordinate2D(latitude: 35.0, longitude: -97.0))
            #expect(Bool(false), "Expected NwsError.missingData")
        } catch let error as NwsError {
            #expect(error == .missingData)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test("cancellation errors pass through")
    func cancellation_isPropagated() async throws {
        let http = MockHTTPClient(
            response: HTTPResponse(status: 200, headers: [:], data: Data()),
            error: CancellationError()
        )
        let client = NwsHttpClient(http: http)

        do {
            _ = try await client.fetchPointMetadata(for: Coordinate2D(latitude: 35.1, longitude: -97.1))
            #expect(Bool(false), "Expected CancellationError")
        } catch is CancellationError {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
}
