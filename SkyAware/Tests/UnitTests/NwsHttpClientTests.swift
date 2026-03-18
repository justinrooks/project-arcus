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
    
    func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
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
        #expect(components.queryItems?.first(where: { $0.name == "status" })?.value == "actual")
        #expect(components.queryItems?.first(where: { $0.name == "message_type" })?.value == "alert,update")
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

private actor ArcusMockHTTPClientState {
    var requests: [(method: String, url: URL, headers: [String: String], body: Data?)] = []

    func record(method: String, url: URL, headers: [String: String], body: Data?) {
        requests.append((method: method, url: url, headers: headers, body: body))
    }

    func firstRequest() -> (method: String, url: URL, headers: [String: String], body: Data?)? {
        requests.first
    }
}

private final class ArcusMockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = ArcusMockHTTPClientState()
    private let response: HTTPResponse
    private let error: Error?

    init(response: HTTPResponse, error: Error? = nil) {
        self.response = response
        self.error = error
    }

    func get(_ url: URL, headers: [String : String]) async throws -> HTTPResponse {
        await state.record(method: "GET", url: url, headers: headers, body: nil)

        if let error {
            throw error
        }
        return response
    }

    func post(_ url: URL, headers: [String : String], body: Data?) async throws -> HTTPResponse {
        await state.record(method: "POST", url: url, headers: headers, body: body)

        if let error {
            throw error
        }
        return response
    }

    func clearCache() {}

    func firstRequest() async -> (method: String, url: URL, headers: [String: String], body: Data?)? {
        await state.firstRequest()
    }
}

@Suite("ArcusHttpClient")
struct ArcusHttpClientTests {
    @Test("fetchActiveAlerts builds alerts endpoint from Arcus signal base URL")
    func fetchActiveAlerts_buildsArcusAlertsURL() async throws {
        let payload = Data("{\"ok\":true}".utf8)
        let http = ArcusMockHTTPClient(response: HTTPResponse(status: 200, headers: [:], data: payload))
        let client = ArcusHttpClient(baseURL: URL(string: "https://arcus.example.com")!, http: http)

        let data = try await client.fetchActiveAlerts(
            for: "COC001",
            or: "COZ245",
            in: 613725958748241919
        )

        #expect(data == payload)

        let request = try #require(await http.firstRequest())
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        #expect(request.method == "GET")
        #expect(components.scheme == "https")
        #expect(components.host == "arcus.example.com")
        #expect(components.path == ArcusSignalConfiguration.alertsPath)
        #expect(components.queryItems?.first(where: { $0.name == "ugc" })?.value == "COC001")
        #expect(components.queryItems?.first(where: { $0.name == "fire" })?.value == "COZ245")
        #expect(components.queryItems?.first(where: { $0.name == "h3" })?.value == "613725958748241919")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
    }
}

@Suite("HTTPLocationSnapshotUploader")
struct HTTPLocationSnapshotUploaderTests {
    @Test("upload builds location snapshot endpoint from Arcus signal base URL")
    func upload_buildsLocationSnapshotsURL() async throws {
        let http = ArcusMockHTTPClient(response: HTTPResponse(status: 202, headers: [:], data: nil))
        let uploader = HTTPLocationSnapshotUploader(
            baseURL: URL(string: "https://arcus.example.com")!,
            http: http
        )

        let payload = LocationSnapshotPushPayload(
            capturedAt: Date(timeIntervalSince1970: 1_710_000_000),
            locationAgeSeconds: 5,
            horizontalAccuracyMeters: 12,
            cellScheme: "h3",
            h3Cell: 613725958748241919,
            h3Resolution: 8,
            countyCode: "COC001",
            forecastZone: "COZ245",
            fireZone: "COZ245",
            apnsDeviceToken: "abc123",
            installationId: "install-1",
            source: "unit-test",
            auth: "always",
            appVersion: "1.0",
            buildNumber: "1",
            platform: "iOS",
            osVersion: "18.0",
            apnsEnvironment: "sandbox",
            countyLabel: "Adams County",
            fireZoneLabel: "Front Range",
            isSubscribed: true
        )

        try await uploader.upload(payload)

        let request = try #require(await http.firstRequest())
        #expect(request.method == "POST")
        #expect(request.url.scheme == "https")
        #expect(request.url.host == "arcus.example.com")
        #expect(request.url.path == ArcusSignalConfiguration.locationSnapshotsPath)
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
        #expect(request.body?.isEmpty == false)
    }
}
