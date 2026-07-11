import ArcusCore
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

    func requestCount() -> Int {
        requests.count
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

    func requestCount() async -> Int {
        await state.requestCount()
    }
}

@Suite("StormSetupHTTPClient")
struct StormSetupHTTPClientTests {
    @Test("request construction uses canonical H3 query and Arcus headers")
    func requestConstructionUsesCanonicalH3QueryAndHeaders() async throws {
        let payload = try encodedStormSetupPayload(profileAnalysis: nil)
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        _ = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        let request = try #require(await http.firstRequest())
        let components = try #require(URLComponents(url: request.url, resolvingAgainstBaseURL: false))

        #expect(await http.requestCount() == 1)
        #expect(request.method == "GET")
        #expect(components.scheme == "https")
        #expect(components.host == "api.skyaware.app")
        #expect(components.path == "/api/v1/storm-setup/current")
        #expect(components.queryItems?.first(where: { $0.name == "h3" })?.value == "613160066540896255")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["User-Agent"]?.isEmpty == false)
    }

    @Test("successful decoding preserves ISO-8601 dates, embedded profile analysis, and viability enums")
    func successfulDecodingPreservesIso8601DatesEmbeddedProfileAnalysisAndViabilityEnums() async throws {
        let payload = try encodedStormSetupPayload(
            setup: .init(
                h3Cell: 613_160_066_540_896_255,
                centroid: .init(latitude: 39.5, longitude: -100.0),
                source: .init(
                    model: .hrrr,
                    product: .wrfsfc,
                    domain: .conus,
                    runTime: iso8601Date("2026-06-01T18:00:00Z"),
                    forecastHour: 6,
                    validTime: iso8601Date("2026-06-01T21:00:00Z"),
                    fieldSetVersion: .tornadoV1,
                    bbox: .init(leftlon: -104.3, rightlon: -96.2, toplat: 41.5, bottomlat: 36.8),
                    primaryDownloadURL: URL(string: "https://example.invalid/storm-setup"),
                    idxURL: nil
                ),
                surfaceHeightMslM: 1340,
                freshness: .init(
                    sourceValidTime: iso8601Date("2026-06-01T21:00:00Z"),
                    modelRunTime: iso8601Date("2026-06-01T18:00:00Z"),
                    forecastHour: 6,
                    fetchedAt: iso8601Date("2026-06-01T21:03:00Z"),
                    expiresAt: iso8601Date("2026-06-01T22:00:00Z"),
                    isStale: false,
                    isDegraded: false
                )
            ),
            profileAnalysis: makeProfileAnalysisResponse(),
            tornadoViability: .init(
                overall: .supportive,
                realization: .realized,
                primaryFailureMode: .none,
                confidence: .moderate,
                summary: "Supportive setup.",
                details: .init(
                    stormViability: .supportive,
                    supercellViability: .strong,
                    tornadoEfficiency: .supportive,
                    inhibition: .weak,
                    instability: .supportive,
                    moisture: .strong,
                    cloudBase: .weak,
                    deepShear: .strong,
                    lowLevelRotation: .conditional,
                    lowLevelStretching: .supportive,
                    cloudBaseEfficiency: .supportive,
                    supercellComposite: .strong,
                    tornadoComposite: .supportive,
                    stormMode: .conditional
                ),
                limitingFactors: [.strongCap, .poorMoisture]
            )
        )
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        let response = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        #expect(response.setup.freshness.modelRunTime == iso8601Date("2026-06-01T18:00:00Z"))
        #expect(response.setup.freshness.sourceValidTime == iso8601Date("2026-06-01T21:00:00Z"))
        #expect(response.setup.freshness.forecastHour == 6)
        #expect(response.setup.source.validTime == iso8601Date("2026-06-01T21:00:00Z"))
        #expect(response.setup.surfaceHeightMslM == 1340)
        #expect(response.profileAnalysis?.ship == 2.1)
        #expect(response.profileAnalysis?.quality.profileLevelCount == 36)
        #expect(response.tornadoViability.realization == .realized)
        #expect(response.tornadoViability.primaryFailureMode == .none)
        #expect(response.tornadoViability.confidence == .moderate)
        #expect(response.tornadoViability.limitingFactors == [.strongCap, .poorMoisture])
    }

    @Test("nil profile analysis decodes successfully")
    func nilProfileAnalysisDecodesSuccessfully() async throws {
        let payload = try encodedStormSetupPayload(profileAnalysis: nil)
        let http = StormSetupMockHTTPClient(
            response: HTTPResponse(status: 304, headers: [:], data: payload, source: .cacheRevalidated304)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        let response = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        #expect(response.profileAnalysis == nil)
        #expect(response.setup.freshness.expiresAt == iso8601Date("2026-06-01T22:00:00Z"))
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
            response: HTTPResponse(status: 200, headers: [:], data: try encodedStormSetupPayload(profileAnalysis: nil)),
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
            response: HTTPResponse(status: 200, headers: [:], data: try encodedStormSetupPayload(profileAnalysis: nil), source: .localCache)
        )
        let client = StormSetupHTTPClient(baseURL: URL(string: "https://api.skyaware.app")!, http: http)

        let response = try await client.fetchCurrentStormSetup(h3Cell: 613_160_066_540_896_255)

        #expect(response.setup.source.model == .hrrr)
        #expect(response.tornadoViability.confidence == .moderate)
        #expect(response.tornadoViability.summary == "Supportive setup.")
    }
}

private func encodedStormSetupPayload(
    setup: StormSetupCurrentSetupResponse = .init(
        h3Cell: 613_160_066_540_896_255,
        centroid: .init(latitude: 39.5, longitude: -100.0),
        source: .init(
            model: .hrrr,
            product: .wrfsfc,
            domain: .conus,
            runTime: iso8601Date("2026-06-01T18:00:00Z"),
            forecastHour: 6,
            validTime: iso8601Date("2026-06-01T21:00:00Z"),
            fieldSetVersion: .tornadoV1,
            bbox: .init(leftlon: -104.3, rightlon: -96.2, toplat: 41.5, bottomlat: 36.8),
            primaryDownloadURL: URL(string: "https://example.invalid/storm-setup"),
            idxURL: nil
        ),
        surfaceHeightMslM: 1340,
        freshness: .init(
            sourceValidTime: iso8601Date("2026-06-01T21:00:00Z"),
            modelRunTime: iso8601Date("2026-06-01T18:00:00Z"),
            forecastHour: 6,
            fetchedAt: iso8601Date("2026-06-01T21:03:00Z"),
            expiresAt: iso8601Date("2026-06-01T22:00:00Z"),
            isStale: false,
            isDegraded: false
        )
    ),
    ingredients: StormSetupTornadoIngredientsResponse = .init(
        canonical: .init(
            sbcapeJkg: 1700,
            mlcapeJkg: 1850,
            mucapeJkg: 2200.5,
            mlcinJkg: -42,
            dcapeJkg: nil,
            mllclM: 980,
            tempDewPtDeltaF: 4.5,
            threeCapeJkg: 95,
            lclLfcSeparationM: nil,
            lapseRate03kmCkm: nil,
            lapseRate700500mbCkm: nil,
            shear06kmKt: 42,
            shear03kmKt: 31,
            shear01kmKt: 18,
            effectiveShearKt: nil,
            srh01kmM2s2: 125.5,
            srh03kmM2s2: 175,
            effectiveSrhM2s2: nil,
            supercellComposite: nil,
            significantTornadoFixed: nil,
            significantTornadoEffective: nil,
            significantHail: nil,
            bunkersRightMotion: nil,
            bunkersLeftMotion: nil,
            stormRelativeWind46km: nil,
            meanWind850300mb: nil,
            diagnostics: nil,
            effectiveBulkShearMs: nil,
            effectiveLayer: nil,
            stormMotion: nil
        ),
        diagnostics: .empty
    ),
    profileAnalysis: AnvilAnalyzeProfileResponse? = makeProfileAnalysisResponse(),
    tornadoViability: TornadoViabilityReport = .init(
        overall: .supportive,
        realization: .realized,
        primaryFailureMode: .none,
        confidence: .moderate,
        summary: "Supportive setup.",
        details: .init(
            stormViability: .supportive,
            supercellViability: .strong,
            tornadoEfficiency: .supportive,
            inhibition: .weak,
            instability: .supportive,
            moisture: .strong,
            cloudBase: .weak,
            deepShear: .strong,
            lowLevelRotation: .conditional,
            lowLevelStretching: .supportive,
            cloudBaseEfficiency: .supportive,
            supercellComposite: .strong,
            tornadoComposite: .supportive,
            stormMode: .conditional
        ),
        limitingFactors: [.strongCap, .poorMoisture]
    )
) throws -> Data {
    let response = StormSetupCurrentResponse(
        setup: setup,
        ingredients: ingredients,
        profileAnalysis: profileAnalysis,
        tornadoViability: tornadoViability
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(response)
}

private func makeProfileAnalysisResponse() -> AnvilAnalyzeProfileResponse? {
    .init(
        effectiveLayer: .init(
            status: "found",
            basePressureMb: 915,
            topPressureMb: 750,
            baseMetersAgl: 850,
            topMetersAgl: 1_800
        ),
        stormMotion: .init(
            status: "found",
            bunkersRight: .init(
                uKt: 12.0,
                vKt: -8.0,
                speedKt: 18.0,
                directionTowardDeg: 215.0,
                uMs: 6.2,
                vMs: -4.1,
                speedMs: 9.2
            )
        ),
        mucape: 2_200.5,
        mlcape: 1_850,
        mlcin: -42,
        mllclMetersAgl: 980,
        effectiveSrh: 135,
        effectiveBulkShearMs: 24.5,
        scp: 0.7,
        stpCin: 0.9,
        stpFixed: 1.2,
        ship: 2.1,
        srh01km: nil,
        srh03km: nil,
        sbcape: nil,
        sbcin: nil,
        bulkShear06kmMs: nil,
        lapserate03km: nil,
        threeCapeJkg: nil,
        quality: .init(profileLevelCount: 36, warnings: [])
    )
}

private func iso8601Date(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
