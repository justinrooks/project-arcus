#if DEBUG
import Foundation
import Testing
@testable import SkyAware

struct WSSIAcquisitionProbeTests {
    private typealias Probe = WSSIAcquisitionProbe
    private let environment = Probe.Environment(device: "Simulator", runtime: "Test", build: "Debug")
    private let revision = UUID()
    private let etag = "W/\"fixture\""

    @Test(arguments: [true, false])
    func coldAndConditionalKeepNetworkAndCacheBytesSeparate(hasCacheBody: Bool) async throws {
        let origin = try #require(URL(string: "https://forge.example"))
        let path = geometryPath
        let body = geometryBody(revision: revision)
        let manifest = try makeManifest(path: path)
        let cache = URLCache(memoryCapacity: 1_024 * 1_024, diskCapacity: 0)
        let probe = Probe(origin: origin, cache: cache) { request in
            if request.url?.path == "/v1/wssi/manifest" {
                return try Self.transfer(request, status: 200, body: manifest)
            }
            #expect(request.url?.path == path)
            #expect(request.url?.host == origin.host)
            if let validator = request.value(forHTTPHeaderField: "If-None-Match") {
                #expect(validator == etag)
                if !hasCacheBody { cache.removeAllCachedResponses() }
                return try Self.transfer(request, status: 304, etag: etag, bytes: 0)
            }
            return try Self.transfer(request, status: 200, body: body, etag: etag, bytes: 4)
        }

        let result = try await probe.run(environment: environment)
        let report = result.report
        #expect(report.stop == nil)
        #expect(report.datasets.count == 15)
        #expect(report.datasets.first { $0.slot == .overallDayOne }?.accepted?.revision == revision)
        #expect(report.requests.map(\.stage) == [.manifest, .coldGeometry, .conditionalGeometry])
        #expect(report.requests.map(\.status) == [200, 200, 304])
        let cold = try #require(report.requests.first { $0.stage == .coldGeometry })
        #expect(cold.networkBodyBytes == 4)
        #expect(cold.responseBodyBytes == body.count)
        let conditional = try #require(report.requests.last)
        #expect(conditional.source == .network)
        #expect(conditional.networkBodyBytes == 0)
        #expect(conditional.responseBodyBytes == 0)
        #expect(conditional.outcome == (hasCacheBody ? .cacheRevalidated : .missingCachedBody))
        #expect(conditional.reusedCacheBodyBytes == (hasCacheBody ? body.count : nil))
        #expect(result.geometry == body)
    }

    @Test(arguments: [404, 503])
    func geometryHTTPFailureIsRecordedWithoutRetry(status: Int) async throws {
        let origin = try #require(URL(string: "https://forge.example"))
        let manifest = try makeManifest(path: geometryPath)
        let probe = Probe(origin: origin) { request in
            if request.url?.path == "/v1/wssi/manifest" {
                return try Self.transfer(request, status: 200, body: manifest)
            }
            return try Self.transfer(request, status: status, body: Data("error".utf8))
        }

        let result = try await probe.run(environment: environment)
        #expect(result.geometry == nil)
        #expect(result.report.requests.map(\.status) == [200, status])
        #expect(result.report.requests.last?.outcome == .httpError)
    }

    @Test(arguments: ["/v1/wssi/Overall_Impact/days/2/revisions/other/geometry", "//other.example/geometry", nil])
    func absentOrMismatchedRevisionDoesNotRequestGeometry(path: String?) async throws {
        let origin = try #require(URL(string: "https://forge.example"))
        let manifest = try makeManifest(path: path)
        let probe = Probe(origin: origin) { request in
            #expect(request.url?.path == "/v1/wssi/manifest")
            return try Self.transfer(request, status: 200, body: manifest)
        }

        let result = try await probe.run(environment: environment)
        #expect(result.geometry == nil)
        #expect(result.report.requests.count == 1)
        #expect(result.report.stop == (path == nil ? .noAcceptedRevision : .invalidGeometryPath))
    }

    @Test(arguments: [true, false])
    func incorrectGeometryIdentityIsMeasuredButNeverReturned(coldIsIncorrect: Bool) async throws {
        let origin = try #require(URL(string: "https://forge.example"))
        let manifest = try makeManifest(path: geometryPath)
        let correct = geometryBody(revision: revision)
        let incorrect = geometryBody(revision: UUID())
        let probe = Probe(origin: origin) { request in
            if request.url?.path == "/v1/wssi/manifest" {
                return try Self.transfer(request, status: 200, body: manifest)
            }
            let isConditional = request.value(forHTTPHeaderField: "If-None-Match") != nil
            let body = coldIsIncorrect || isConditional ? incorrect : correct
            return try Self.transfer(request, status: 200, body: body, etag: etag)
        }

        let result = try await probe.run(environment: environment)
        #expect(result.report.requests.count == (coldIsIncorrect ? 2 : 3))
        #expect(result.report.requests.last?.status == 200)
        #expect(result.report.requests.last?.outcome == .invalidGeometryIdentity)
        #expect(result.report.requests.last?.responseBodyBytes == incorrect.count)
        #expect(result.geometry == (coldIsIncorrect ? nil : correct))
    }

    @Test
    func contradictoryNotModifiedValidatorDoesNotClaimCacheReuse() async throws {
        let origin = try #require(URL(string: "https://forge.example"))
        let manifest = try makeManifest(path: geometryPath)
        let body = geometryBody(revision: revision)
        let probe = Probe(origin: origin) { request in
            if request.url?.path == "/v1/wssi/manifest" {
                return try Self.transfer(request, status: 200, body: manifest)
            }
            if request.value(forHTTPHeaderField: "If-None-Match") != nil {
                return try Self.transfer(request, status: 304, etag: #""different""#, bytes: 0)
            }
            return try Self.transfer(request, status: 200, body: body, etag: etag)
        }

        let result = try await probe.run(environment: environment)
        #expect(result.report.requests.last?.outcome == .conflictingValidator)
        #expect(result.report.requests.last?.reusedCacheBodyBytes == nil)
        #expect(result.geometry == body)
    }

    @Test
    func transportFailureHasNoInventedStatusOrSizes() async throws {
        let origin = try #require(URL(string: "https://forge.example"))
        let probe = Probe(origin: origin) { _ in throw URLError(.notConnectedToInternet) }
        let result = try await probe.run(environment: environment)
        let record = try #require(result.report.requests.first)
        #expect(result.report.stop == .manifestUnavailable)
        #expect(record.outcome == .transportError)
        #expect(record.transportErrorCode == URLError.Code.notConnectedToInternet.rawValue)
        #expect(record.status == nil)
        #expect(record.networkBodyBytes == nil)
        #expect(record.responseBodyBytes == nil)
    }

    private func geometryBody(revision: UUID) -> Data {
        Data("""
        {"type":"FeatureCollection","metadata":{"product":"Overall_Impact","day":1,"revision":"\(revision)"},"features":[]}
        """.utf8)
    }

    private var geometryPath: String {
        "/v1/wssi/Overall_Impact/days/1/revisions/\(revision.uuidString.lowercased())/geometry"
    }

    private func makeManifest(path: String?) throws -> Data {
        let datasets = ["Overall_Impact", "Snow_Amount", "Snow_Load", "Ice_Accumulation", "Blowing_Snow"].flatMap {
            product in (1...3).map { day in
                let accepted = product == "Overall_Impact" && day == 1 ? path.map {
                    Probe.Revision(
                        revision: revision, issuedAt: "2026-11-23T19:15:00Z",
                        validFrom: "2026-11-23T18:00:00Z", validTo: "2026-11-24T18:00:00Z",
                        gisFileDate: nil, gisIngestDate: nil, retrievedAt: "2026-11-23T20:30:38Z", geometryPath: $0
                    )
                } : nil
                return Probe.Dataset(
                    product: product, day: day, validity: accepted == nil ? "NeverAccepted" : "Valid",
                    sourceStatus: "Available", coverage: "unknown", accepted: accepted
                )
            }
        }
        return try JSONEncoder().encode(["datasets": datasets])
    }

    private static func transfer(
        _ request: URLRequest, status: Int, body: Data = Data(), etag: String? = nil, bytes: Int64? = nil
    ) throws -> Probe.Transfer {
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: etag.map { ["ETag": $0] }
        ))
        return Probe.Transfer(body: body, response: response, source: .network, networkBodyBytes: bytes)
    }
}
#endif
