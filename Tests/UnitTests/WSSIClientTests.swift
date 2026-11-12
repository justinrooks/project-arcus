import Foundation
import Testing
@testable import SkyAware

@Suite("WSSI acquisition")
struct WSSIClientTests {
    private func scope() throws -> WSSIScope {
        try WSSIScope(south: 36, west: -112, north: 43, east: -102)
    }

    @Test("retrieves twenty layers and retains complete geometry and HTTP provenance")
    func complete() async throws {
        let fixture = Fixture()
        let client = try WSSIClient(limits: .init(pageSize: 1), transport: { try await fixture.get($0, $1) })
        let result = try await client.acquire(scope: scope())
        #expect(result.scope == (try scope()))
        #expect(result.layers.map(\.id) == [1,2,3,4,6,7,8,9,11,12,13,14,16,17,18,19,24,25,26,27])
        #expect(result.layers.allSatisfy { $0.collection.features.count == 2 && $0.requests.count == 4 })
        #expect(result.layers[0].collection.features[0].polygons[0].rings[0][0].longitude == -120)
        #expect(result.layers[0].requests[0].headers["ETag"] == "test")
        #expect(await fixture.count == 80)
    }

    @Test("empty complete data remains retrieval evidence without publication identity")
    func empty() async throws {
        let fixture = Fixture(mode: .empty)
        let result = try await WSSIClient(transport: { try await fixture.get($0, $1) }).acquire(scope: scope())
        #expect(result.layers.count == 20)
        #expect(result.layers.allSatisfy { $0.collection.features.isEmpty && $0.requests.count == 3 })
    }

    @Test("rejects incomplete, duplicate, changing, misidentified and failed responses",
          arguments: [Mode.duplicate, .missing, .changed, .truncated, .wrongLayer, .apiError, .httpError,
                      .oversized, .cacheFallback, .notModified, .badIDs])
    func rejects(mode: Mode) async throws {
        let fixture = Fixture(mode: mode)
        let client = try WSSIClient(limits: .init(pageSize: 1), transport: { try await fixture.get($0, $1) })
        await #expect(throws: (any Error).self) { try await client.acquire(scope: scope()) }
    }

    @Test("bounds features, individual responses and cumulative acquisition bytes")
    func bounds() async throws {
        for limits in [WSSIClient.Limits(maximumFeaturesPerLayer: 1),
                       .init(maximumResponseBytes: 1), .init(maximumTotalBytes: 1)] {
            let fixture = Fixture()
            let client = try WSSIClient(limits: limits, transport: { try await fixture.get($0, $1) })
            await #expect(throws: WSSIAcquisitionError.self) { try await client.acquire(scope: scope()) }
        }
    }

    @Test("propagates transport timeout without partial output or retry")
    func timeout() async throws {
        let fixture = Fixture(mode: .timeout)
        let client = try WSSIClient(transport: { try await fixture.get($0, $1) })
        await #expect(throws: URLError(.timedOut)) { try await client.acquire(scope: scope()) }
        #expect(await fixture.count == 2)
    }

    @Test("cancels in-flight acquisition")
    func cancellation() async throws {
        let fixture = Fixture(mode: .suspend)
        let client = try WSSIClient(transport: { try await fixture.get($0, $1) })
        let region = try scope()
        let task = Task { try await client.acquire(scope: region) }
        await fixture.waitForStart()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await fixture.count == 1)
    }

    @Test("depletes the aggregate budget across successful requests")
    func cumulativeBudget() async throws {
        let fixture = Fixture()
        let client = try WSSIClient(limits: .init(maximumTotalBytes: 100),
                                    transport: { try await fixture.get($0, $1) })
        await #expect(throws: WSSIAcquisitionError.responseTooLarge) { try await client.acquire(scope: scope()) }
        let ceilings = await fixture.ceilings
        #expect(ceilings.count == 2)
        #expect(ceilings[0] == 100)
        #expect(ceilings[1] > 0 && ceilings[1] < ceilings[0])
    }

    @Test("production downloader bounds unknown-length bodies and propagates timeout and cancellation")
    func streamingTransport() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LocalProtocol.self]
        let url = try #require(URL(string: "https://wssi.test/body"))
        // Allow simulator scheduling under the full parallel regression lane.
        let request = URLRequest(url: url, timeoutInterval: 30)
        let response = try await WSSIClient.download(request, maximumBytes: 8, configuration: configuration)
        #expect(response.data == Data(repeating: 65, count: 8))
        await #expect(throws: WSSIAcquisitionError.responseTooLarge) {
            try await WSSIClient.download(request, maximumBytes: 4, configuration: configuration)
        }
        let stall = try #require(URL(string: "https://wssi.test/stall"))
        let short = URLRequest(url: stall, timeoutInterval: 0.1)
        do {
            _ = try await WSSIClient.download(short, maximumBytes: 8, configuration: configuration)
            Issue.record("Expected a timeout")
        } catch {
            #expect((error as? URLError)?.code == .timedOut)
        }
        let task = Task {
            try await WSSIClient.download(URLRequest(url: stall, timeoutInterval: 30),
                                          maximumBytes: 8, configuration: configuration)
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError || (error as? URLError)?.code == .cancelled)
        }
    }

    /// Per-request behavior; no mutable global fixtures or process-wide URLProtocol registration.
    final class LocalProtocol: URLProtocol, @unchecked Sendable {
        override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "wssi.test" }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let url = request.url, url.path == "/body",
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                                 headerFields: [:]) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(repeating: 65, count: 8))
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    @Test("revalidates unchanged bodies and replaces changed source responses")
    func conditionalResponses() async throws {
        for mode in [Mode.unchanged, .changedResponse] {
            let fixture = Fixture(mode: mode)
            let client = try WSSIClient(transport: { try await fixture.get($0, $1) })
            let initial = try await client.acquire(scope: scope())
            let next = try await client.acquire(scope: scope(), previous: initial)
            #expect(next.layers.count == 20)
            #expect(next.layers.allSatisfy { $0.collection.features.count == 2 })
            if mode == .unchanged {
                #expect(next.layers.flatMap(\.requests).allSatisfy { $0.status == 304 && $0.byteCount == 0 })
                #expect(next.layers[0].collection == initial.layers[0].collection)
            } else {
                #expect(next.layers[0].collection.features[0].impact == .moderate)
                #expect(next.layers.flatMap(\.requests).allSatisfy { $0.status == 200 })
            }
        }
    }

    @Test("does not reuse bodies after moving beyond prior coverage")
    func scopeIsolation() async throws {
        let original = Fixture()
        let prior = try await WSSIClient(transport: { try await original.get($0, $1) }).acquire(scope: scope())
        let moved = Fixture(geometry: "-111.0,36.0,-102.0,43.0")
        let client = try WSSIClient(transport: { try await moved.get($0, $1) })
        let region = try WSSIScope(south: 36, west: -111, north: 43, east: -102)
        let result = try await client.acquire(scope: region, previous: prior)
        #expect(result.scope == region)
        #expect(result.layers.flatMap(\.requests).allSatisfy { $0.status == 200 })
    }

    enum Mode: Sendable {
        case normal, empty, duplicate, missing, changed, truncated, wrongLayer, apiError, httpError
        case oversized, cacheFallback, notModified, badIDs, timeout, suspend, unchanged, changedResponse
    }

    actor Fixture {
        let mode: Mode
        var count = 0
        var ceilings: [Int] = []
        private var started = false
        let geometry: String
        init(mode: Mode = .normal, geometry: String = "-112.0,36.0,-102.0,43.0") {
            self.mode = mode
            self.geometry = geometry
        }

        func waitForStart() async {
            while !started { await Task.yield() }
        }

        func get(_ request: URLRequest, _ ceiling: Int) async throws -> HTTPResponse {
            count += 1
            ceilings.append(ceiling)
            started = true
            if mode == .suspend { try await Task.sleep(for: .seconds(60)) }
            if mode == .timeout && count == 2 { throw URLError(.timedOut) }
            let url = try #require(request.url)
            let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            #expect(query["geometry"] == geometry)
            #expect(query["inSR"] == "4326" && query["outSR"] == "4326")
            #expect(query["spatialRel"] == "esriSpatialRelIntersects")
            #expect(request.timeoutInterval == 30)
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
            let conditional = request.value(forHTTPHeaderField: "If-None-Match") != nil
            if mode == .unchanged && conditional {
                return HTTPResponse(status: 304, headers: ["ETag": "test"], data: nil)
            }
            if mode != .unchanged && mode != .changedResponse { #expect(!conditional) }
            let id = try #require(Int(url.deletingLastPathComponent().lastPathComponent))
            let bases = [1, 6, 11, 16, 24]
            let group = try #require(bases.lastIndex(where: { $0 <= id }))
            let period = WSSIPeriod.allCases[id - bases[group]]
            let product = WSSIProduct.allCases[group]
            let body: String
            if query["returnIdsOnly"] == "true" {
                let ids = mode == .empty ? "null" : mode == .badIDs ? "[true,2]" :
                    mode == .changed && count == 4 ? "[1,3]" : "[1,2]"
                body = "{\"objectIdFieldName\":\"objectid\",\"objectIds\":\(ids)}"
            } else {
                #expect(query["returnGeometry"] == "true")
                #expect(query["orderByFields"] == "objectid ASC")
                let offset = Int(query["resultOffset"] ?? "0") ?? 0
                let oid = mode == .duplicate ? 1 : offset + 1
                let source = mode == .wrongLayer ? "SNOW_AMOUNT_Day_1" : "\(product.rawValue)_\(period.rawValue)"
                let feature = """
                {"attributes":{"objectid":\(oid),"idp_source":"\(source)","component":"\(product.rawValue)","impact":"MAJOR","issue_time":"2026-11-11 2116Z","start_time":"21Z 11/11/26","end_time":"18Z 11/12/26"},"geometry":{"rings":[[[-120,40],[-120,41],[-99,41],[-99,40],[-120,40]]]}}
                """
                let features = mode == .empty || mode == .missing ? "" : feature
                let more = mode == .truncated ? false : mode != .empty && offset == 0
                body = "{\"geometryType\":\"esriGeometryPolygon\",\"spatialReference\":{\"wkid\":4326},\"features\":[\(features)],\"exceededTransferLimit\":\(more)}"
            }
            let data = mode == .oversized ? Data(repeating: 0, count: ceiling + 1) :
                Data((mode == .apiError ? "{\"error\":{\"code\":400}}" :
                      mode == .changedResponse && conditional ? body.replacingOccurrences(of: "MAJOR", with: "MODERATE") : body).utf8)
            return HTTPResponse(status: mode == .httpError ? 503 : mode == .notModified ? 304 : 200,
                                headers: ["ETag": mode == .changedResponse && conditional ? "changed" : "test"], data: data,
                                source: mode == .cacheFallback ? .cacheFallback : .live)
        }
    }
}
