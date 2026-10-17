import ArcusCore
import Foundation
import Testing
import SwiftData
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

private func encodedMesoPayload(issued: Date, probability: Double = 40, text: String = "40%") throws -> Data {
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
        watchProbability: probability,
        watchProbabilityText: text,
        threats: MesoscaleDiscussionThreats(peakWindMPH: 70, hailRangeInches: 1.5, tornadoStrength: "EF2"),
        coordinates: [MesoscaleDiscussionCoordinate(latitude: 39.5, longitude: -104.8)]
    )
    return try JSONEncoder().encode([payload])
}


@Suite("Remote meso resolution")
struct RemoteMesoResolutionTests {
    private let now = Date(timeIntervalSince1970: 2_064_333_600) // 2035-06-01

    @Test("cold fetch accepts only the target; warm replay uses saved state without HTTP")
    func coldAndWarmResolution() async throws {
        let container = try await makeContainer()
        let repo = MesoRepo(modelContainer: container)
        let data = try encodedMesoPayload(issued: now)
        let client = NotificationMesoClient(data: data)
        let provider = ArcusMesoProvider(client: client, repo: repo, now: { now })
        let cold = try #require(try await provider.resolveNotificationMeso(productID: "SPC-MD-2035-1234"))
        #expect(cold.productID == "SPC-MD-2035-1234")
        #expect(cold.watchProbability == 40)
        #expect(cold.watchProbabilityText == "40%")
        #expect(try await provider.resolveNotificationMeso(productID: cold.productID) == cold)
        #expect(await client.targetCalls == [cold.productID])
        #expect(await client.collectionCalls == 0)
    }

    @Test("expired, future, mismatched, missing, failed and non-authoritative targets are unavailable",
          arguments: ["expired", "future", "mismatch", "missing", "failed", "fallback", "local"])
    func rejectsUnavailableTargets(scenario: String) async throws {
        let repo = MesoRepo(modelContainer: try await makeContainer())
        let issued = scenario == "expired" ? now.addingTimeInterval(-10_800)
            : scenario == "future" ? now.addingTimeInterval(60) : now
        let client = NotificationMesoClient(
            data: try encodedMesoPayload(issued: issued),
            source: scenario == "fallback" ? .cacheFallback : scenario == "local" ? .localCache : .live,
            status: scenario == "missing" ? 404 : scenario == "failed" ? 503 : 200
        )
        let provider = ArcusMesoProvider(client: client, repo: repo, now: { now })
        let id = scenario == "mismatch" ? "SPC-MD-2035-1235" : "SPC-MD-2035-1234"
        do {
            #expect(try await provider.resolveNotificationMeso(productID: id) == nil)
            #expect(scenario != "failed")
        } catch {
            #expect(scenario == "failed")
        }
        #expect(try await repo.notificationMeso(productID: id, at: now) == nil)
    }

    @Test("overlapping receipt/open callers share targeted fetch and accepted result")
    func overlappingResolutionCoalesces() async throws {
        let repo = MesoRepo(modelContainer: try await makeContainer())
        let client = NotificationMesoClient(data: try encodedMesoPayload(issued: now), gated: true)
        let provider = ArcusMesoProvider(client: client, repo: repo, now: { now })
        let first = Task { try await provider.resolveNotificationMeso(productID: "SPC-MD-2035-1234") }
        await client.waitUntilStarted()
        let second = Task { try await provider.resolveNotificationMeso(productID: "SPC-MD-2035-1234") }
        while await provider.coalescedTargetCount == 0 { await Task.yield() }
        await client.release()
        let a = try await first.value
        let b = try await second.value
        #expect(a != nil)
        #expect(a == b)
        #expect(await client.targetCalls.count == 1)
    }

    @Test("a cancelled waiter cannot publish but does not cancel shared acceptance")
    func cancelledWaiterPreservesSharedWork() async throws {
        let repo = MesoRepo(modelContainer: try await makeContainer())
        let client = NotificationMesoClient(data: try encodedMesoPayload(issued: now), gated: true)
        let provider = ArcusMesoProvider(client: client, repo: repo, now: { now })
        let first = Task { try await provider.resolveNotificationMeso(productID: "SPC-MD-2035-1234") }
        await client.waitUntilStarted()
        first.cancel()
        await client.release()
        do { _ = try await first.value; Issue.record("Cancelled waiter should throw") }
        catch { #expect(error is CancellationError) }
        #expect(try await provider.acceptedNotificationMeso(productID: "SPC-MD-2035-1234") != nil)
    }

    @Test("accepted target preserves canonical probability across disk reopen without changing Home state",
          arguments: ["40%", "80 percent"])
    @MainActor
    func targetedAcceptanceSurvivesReopen(text: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let schema = Schema([MD.self, HomeProjection.self])
        let config = ModelConfiguration(schema: schema, url: root.appendingPathComponent("meso.store"))
        let id = "SPC-MD-2035-1234"
        let probability: Double = text == "80 percent" ? 80 : 40
        let payload = try JSONDecoder().decode(
            [MesoscaleDiscussionPayload].self,
            from: encodedMesoPayload(issued: now, probability: probability, text: text)
        )[0]
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            let snapshot = LocationSnapshot(coordinates: .init(latitude: 39, longitude: -104),
                                            timestamp: now, accuracy: 25, placemarkSummary: "Colorado", h3Cell: 123)
            let grid = GridPointSnapshot(
                nwsId: "BOU/10,20", latitude: 39, longitude: -104, gridId: "BOU", gridX: 10, gridY: 20,
                forecastURL: nil, forecastHourlyURL: nil, forecastGridDataURL: nil, observationStationsURL: nil,
                city: "Denver", state: "CO", timeZoneId: "America/Denver", radarStationId: nil,
                forecastZone: "COZ001", countyCode: "COC001", fireZone: "COZ201", countyLabel: nil, fireZoneLabel: nil
            )
            let home = HomeProjection(context: LocationContext(snapshot: snapshot, h3Cell: 123, grid: grid), createdAt: now)
            let savedMeso = MdDTO(number: 999, title: "Other discussion", link: payload.sourceURL,
                                 issued: now, validStart: now, validEnd: now.addingTimeInterval(3_600),
                                 areasAffected: "Colorado", summary: "Saved", watchProbability: "Unknown",
                                 threats: nil, coordinates: [])
            home.activeMesos = [savedMeso]
            home.lastHotAlertsLoadAt = now.addingTimeInterval(-60)
            context.insert(home)
            try context.save()
            let repo = MesoRepo(modelContainer: container)
            let accepted = try #require(try await repo.acceptNotificationMeso(payload, at: now))
            #expect(accepted.watchProbability == probability)
            // The existing detail consumes this adapter's numeric percentage directly.
            #expect(MdDTO(payload: accepted).watchProbability == probability)
            let firstID = try #require(try context.fetch(FetchDescriptor<MD>()).first?.id)
            _ = try await repo.acceptNotificationMeso(payload, at: now)
            #expect(try context.fetchCount(FetchDescriptor<MD>()) == 1)
            #expect(try context.fetch(FetchDescriptor<MD>()).first?.id == firstID)
            #expect(home.activeMesos == [savedMeso])
            #expect(home.lastHotAlertsLoadAt == now.addingTimeInterval(-60))
        }
        let reopened = try ModelContainer(for: schema, configurations: config)
        let repo = MesoRepo(modelContainer: reopened)
        let reopenedMeso = try #require(try await repo.notificationMeso(productID: id, at: now))
        #expect(reopenedMeso.watchProbability == probability)
        #expect(MdDTO(payload: reopenedMeso).watchProbability == probability)
        #expect(reopenedMeso.watchProbabilityText == (text == "80 percent" ? "80.0" : text))
        #expect(try await repo.notificationMeso(productID: "SPC-MD-2034-1234", at: now) == nil)
        #expect(try await repo.notificationMeso(productID: id, at: now.addingTimeInterval(10_800)) == nil)
    }

    @Test("Home-only accepted meso cache avoids HTTP; invalid or unaccepted targets still fetch",
          arguments: ["valid", "expired", "future", "wrongYear", "wrongID", "unaccepted"])
    @MainActor
    func homeProjectionCache(scenario: String) async throws {
        let schema = Schema([MD.self, HomeProjection.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let issued = scenario == "expired" ? now.addingTimeInterval(-10_800)
            : scenario == "future" ? now.addingTimeInterval(60) : now
        let payload = try JSONDecoder().decode(
            [MesoscaleDiscussionPayload].self,
            from: encodedMesoPayload(issued: issued, probability: 80, text: "80 percent")
        )[0]
        let snapshot = LocationSnapshot(coordinates: .init(latitude: 39, longitude: -104),
                                        timestamp: now, accuracy: 25, placemarkSummary: "Colorado", h3Cell: 123)
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20", latitude: 39, longitude: -104, gridId: "BOU", gridX: 10, gridY: 20,
            forecastURL: nil, forecastHourlyURL: nil, forecastGridDataURL: nil, observationStationsURL: nil,
            city: "Denver", state: "CO", timeZoneId: "America/Denver", radarStationId: nil,
            forecastZone: "COZ001", countyCode: "COC001", fireZone: "COZ201", countyLabel: nil, fireZoneLabel: nil
        )
        let home = HomeProjection(context: LocationContext(snapshot: snapshot, h3Cell: 123, grid: grid), createdAt: now)
        home.activeMesos = [MdDTO(payload: payload)]
        let acceptedAt: Date? = scenario == "unaccepted" ? nil : now.addingTimeInterval(-60)
        home.lastHotAlertsLoadAt = acceptedAt
        context.insert(home)
        try context.save()
        let client = NotificationMesoClient(data: Data(), status: 503)
        let provider = ArcusMesoProvider(client: client, repo: MesoRepo(modelContainer: container),
                                         homeProjections: HomeProjectionStore(modelContainer: container), now: { now })
        let id = scenario == "wrongYear" ? "SPC-MD-2034-1234"
            : scenario == "wrongID" ? "SPC-MD-2035-1235" : payload.productID
        if scenario == "valid" {
            let resolved = try #require(try await provider.resolveNotificationMeso(productID: id))
            #expect(resolved == payload)
            #expect(MdDTO(payload: resolved).watchProbability == 80)
            #expect(await client.targetCalls.isEmpty)
        } else {
            do { _ = try await provider.resolveNotificationMeso(productID: id); Issue.record("Expected unavailable network") }
            catch { #expect(error as? ArcusError == .networkError(status: 503)) }
            #expect(await client.targetCalls == [id])
        }
        #expect(await client.collectionCalls == 0)
        #expect(try context.fetchCount(FetchDescriptor<MD>()) == 0)
        // Read from a fresh context to verify persisted state, not a stale registered model.
        let saved = try #require(try ModelContext(container).fetch(FetchDescriptor<HomeProjection>()).first)
        #expect(saved.activeMesos == [MdDTO(payload: payload)])
        #expect(saved.lastHotAlertsLoadAt == acceptedAt)
        #expect(saved.updatedAt == now)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: MD.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

private actor NotificationMesoClient: ArcusMesoClient {
    let data: Data
    let source: HTTPResponse.Source
    let status: Int
    let gated: Bool
    private var gate: CheckedContinuation<Void, Never>?
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private(set) var targetCalls: [String] = []
    private(set) var collectionCalls = 0

    init(data: Data, source: HTTPResponse.Source = .live, status: Int = 200, gated: Bool = false) {
        self.data = data; self.source = source; self.status = status; self.gated = gated
    }

    func fetchActiveMesos(h3Cell: Int64?) async throws -> HTTPResponse {
        collectionCalls += 1
        return HTTPResponse(status: 200, headers: [:], data: Data("[]".utf8))
    }

    func fetchMeso(productID: String) async throws -> HTTPResponse {
        targetCalls.append(productID)
        startedWaiter?.resume(); startedWaiter = nil
        if gated { await withCheckedContinuation { gate = $0 } }
        if status != 200 { throw ArcusError.networkError(status: status) }
        return HTTPResponse(status: 200, headers: [:], data: data, source: source)
    }

    func waitUntilStarted() async {
        if targetCalls.isEmpty { await withCheckedContinuation { startedWaiter = $0 } }
    }
    func release() { gate?.resume(); gate = nil }
}
