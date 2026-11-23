#if DEBUG
import Foundation
import Synchronization

/// Temporary Forge experiment. Each run reads the manifest and probes one accepted revision.
actor WSSIAcquisitionProbe {
    struct Slot: Codable, Hashable, Sendable {
        let product: String
        let day: Int

        static let overallDayOne = Self(product: "Overall_Impact", day: 1)
    }

    struct Revision: Codable, Equatable, Sendable {
        let revision: UUID
        let issuedAt: String
        let validFrom: String
        let validTo: String
        let gisFileDate: String?
        let gisIngestDate: String?
        let retrievedAt: String
        let geometryPath: String
    }

    struct Dataset: Codable, Sendable {
        let product: String
        let day: Int
        let validity: String
        let sourceStatus: String
        let coverage: String
        let accepted: Revision?

        var slot: Slot { Slot(product: product, day: day) }
    }

    private struct Manifest: Decodable {
        let datasets: [Dataset]
    }

    private struct GeometryHeader: Decodable {
        struct Identity: Decodable, Equatable {
            let product: String
            let day: Int
            let revision: UUID
        }

        let type: String
        let metadata: Identity
    }

    struct Environment: Codable, Sendable {
        let device: String
        let runtime: String
        let build: String
    }

    enum Source: String, Codable, Sendable {
        case network, urlCache, unknown
    }

    enum Outcome: String, Codable, Sendable {
        case body, cacheRevalidated, missingCachedBody, missingBody, invalidGeometryIdentity
        case conflictingValidator, httpError, transportError
    }

    struct RequestRecord: Codable, Sendable {
        enum Stage: String, Codable, Sendable { case manifest, coldGeometry, conditionalGeometry }

        let stage: Stage
        let status: Int?
        let etag: String?
        let source: Source
        let outcome: Outcome
        let elapsedSeconds: Double
        /// URLSession's received network response-body count before decoding, excluding headers.
        /// Nil means a network transaction could not be reliably attributed.
        let networkBodyBytes: Int64?
        let responseBodyBytes: Int?
        let reusedCacheBodyBytes: Int?
        let transportErrorCode: Int?
    }

    struct Report: Codable, Sendable {
        enum Stop: String, Codable, Sendable {
            case busy, rejectedOrigin, manifestUnavailable, invalidManifest, noAcceptedRevision, invalidGeometryPath
        }

        let startedAt: Date
        let environment: Environment
        let requestedSlot: Slot
        var datasets: [Dataset] = []
        var requests: [RequestRecord] = []
        var stop: Stop?
    }

    struct Result: Sendable {
        let report: Report
        let geometry: Data?
    }

    struct Transfer: Sendable {
        let body: Data
        let response: HTTPURLResponse
        let source: Source
        let networkBodyBytes: Int64?
    }

    typealias Transport = @Sendable (URLRequest) async throws -> Transfer

    private let origin: URL
    private let transport: Transport
    private let cache: URLCache
    private var running = false

    init(origin: URL, cache: URLCache? = nil, transport: Transport? = nil) {
        self.origin = origin
        self.cache = cache ?? URLCache(memoryCapacity: 64 * 1_024 * 1_024, diskCapacity: 0)
        self.transport = transport ?? Self.makeTransport()
    }

    func run(slot: Slot = .overallDayOne, environment: Environment) async throws -> Result {
        var report = Report(startedAt: .now, environment: environment, requestedSlot: slot)
        guard !running else {
            report.stop = .busy
            return Result(report: report, geometry: nil)
        }
        guard let origin = URLComponents(url: origin, resolvingAgainstBaseURL: false),
              origin.scheme == "https" || origin.scheme == "http",
              origin.host?.isEmpty == false, origin.user == nil, origin.password == nil,
              origin.query == nil, origin.fragment == nil,
              origin.path.isEmpty || origin.path == "/" else {
            report.stop = .rejectedOrigin
            return Result(report: report, geometry: nil)
        }
        running = true
        defer { running = false }

        let manifestRequest = request(path: "/v1/wssi/manifest", origin: origin)
        let manifest = try await fetch(manifestRequest, stage: .manifest)
        report.requests.append(manifest.record)
        guard let manifestBody = manifest.body else {
            report.stop = .manifestUnavailable
            return Result(report: report, geometry: nil)
        }
        guard let datasets = try? JSONDecoder().decode(Manifest.self, from: manifestBody).datasets,
              datasets.count == 15, Set(datasets.map(\.slot)) == Self.expectedSlots else {
            report.stop = .invalidManifest
            return Result(report: report, geometry: nil)
        }
        report.datasets = datasets
        guard let accepted = datasets.first(where: { $0.slot == slot })?.accepted else {
            report.stop = .noAcceptedRevision
            return Result(report: report, geometry: nil)
        }
        let revision = accepted.revision.uuidString.lowercased()
        guard accepted.geometryPath == "/v1/wssi/\(slot.product)/days/\(slot.day)/revisions/\(revision)/geometry" else {
            report.stop = .invalidGeometryPath
            return Result(report: report, geometry: nil)
        }

        var geometryRequest = request(path: accepted.geometryPath, origin: origin)
        let identity = GeometryHeader.Identity(product: slot.product, day: slot.day, revision: accepted.revision)
        let cold = try await fetch(geometryRequest, stage: .coldGeometry, identity: identity)
        report.requests.append(cold.record)
        guard let body = cold.body, let etag = cold.record.etag, !etag.isEmpty else {
            return Result(report: report, geometry: cold.body)
        }

        let cacheKey = geometryRequest
        defer { cache.removeCachedResponse(for: cacheKey) }
        geometryRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        let conditional = try await fetch(
            geometryRequest, stage: .conditionalGeometry, identity: identity, cacheKey: cacheKey
        )
        report.requests.append(conditional.record)
        return Result(report: report, geometry: conditional.body ?? body)
    }

    private static let expectedSlots: Set<Slot> = Set(
        ["Overall_Impact", "Snow_Amount", "Snow_Load", "Ice_Accumulation", "Blowing_Snow"].flatMap { product in
            (1...3).map { Slot(product: product, day: $0) }
        }
    )

    private func request(path: String, origin: URLComponents) -> URLRequest {
        var url = origin
        url.path = path
        // The origin was validated above and path is a fixed route or a validated Forge path.
        var request = URLRequest(url: url.url ?? self.origin, cachePolicy: .reloadIgnoringLocalCacheData)
        for (name, value) in HTTPRequestHeaders.arcus() {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    private func fetch(
        _ request: URLRequest, stage: RequestRecord.Stage,
        identity: GeometryHeader.Identity? = nil, cacheKey: URLRequest? = nil
    ) async throws -> (record: RequestRecord, body: Data?) {
        try Task.checkCancellation()
        let start = ContinuousClock.now
        do {
            let transfer = try await transport(request)
            try Task.checkCancellation()
            let elapsed = Self.seconds(since: start)
            let status = transfer.response.statusCode
            let etag = transfer.response.value(forHTTPHeaderField: "ETag")
            let outcome: Outcome
            let body: Data?
            var reusedBytes: Int?
            switch status {
            case 200 where transfer.body.isEmpty:
                outcome = .missingBody
                body = nil
            case 200 where identity.map({ !Self.hasGeometryIdentity($0, in: transfer.body) }) == true:
                outcome = .invalidGeometryIdentity
                body = nil
            case 200:
                outcome = .body
                body = transfer.body
                if stage == .coldGeometry, etag?.isEmpty == false {
                    cache.storeCachedResponse(CachedURLResponse(
                        response: transfer.response, data: transfer.body, storagePolicy: .allowedInMemoryOnly
                    ), for: request)
                }
            case 304:
                let validator = request.value(forHTTPHeaderField: "If-None-Match")
                let cached = cacheKey.flatMap { cache.cachedResponse(for: $0) }
                let cachedETag = (cached?.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
                if let etag, Self.weakETag(etag) != validator.map(Self.weakETag) {
                    outcome = .conflictingValidator
                    body = nil
                } else if let cached, let validator, cachedETag == validator, !cached.data.isEmpty {
                    outcome = .cacheRevalidated
                    body = cached.data
                    reusedBytes = cached.data.count
                } else {
                    outcome = .missingCachedBody
                    body = nil
                }
            default:
                outcome = .httpError
                body = nil
            }
            return (RequestRecord(
                stage: stage, status: status, etag: etag, source: transfer.source, outcome: outcome,
                elapsedSeconds: elapsed, networkBodyBytes: transfer.networkBodyBytes,
                responseBodyBytes: transfer.body.count, reusedCacheBodyBytes: reusedBytes, transportErrorCode: nil
            ), body)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            return (RequestRecord(
                stage: stage, status: nil, etag: nil, source: .unknown, outcome: .transportError,
                elapsedSeconds: Self.seconds(since: start), networkBodyBytes: nil, responseBodyBytes: nil,
                reusedCacheBodyBytes: nil, transportErrorCode: (error as? URLError)?.code.rawValue
            ), nil)
        }
    }

    private static func hasGeometryIdentity(_ identity: GeometryHeader.Identity, in body: Data) -> Bool {
        // Forge writes type and metadata before features. Decode only that bounded header so this
        // acquisition stage does not parse or materialize the geometry being benchmarked later.
        let prefix = body.prefix(4_096)
        guard let features = prefix.range(of: Data(#","features":["#.utf8)),
              let header = try? JSONDecoder().decode(
                GeometryHeader.self, from: prefix[..<features.lowerBound] + Data("}".utf8)
              ) else { return false }
        return header.type == "FeatureCollection" && header.metadata == identity
    }

    private static func weakETag(_ etag: String) -> Substring {
        etag.hasPrefix("W/") ? etag.dropFirst(2) : etag[...]
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    private static func makeTransport() -> Transport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = HTTPRequestPolicy.foreground.requestTimeout
        configuration.timeoutIntervalForResource = HTTPRequestPolicy.foreground.resourceTimeout
        let session = URLSession(configuration: configuration)
        return { request in
            let observer = MetricsObserver()
            let (data, response) = try await session.data(for: request, delegate: observer)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            let measurement = observer.measurement
            return Transfer(body: data, response: response, source: measurement.source,
                            networkBodyBytes: measurement.bytes)
        }
    }

    private final class MetricsObserver: NSObject, URLSessionTaskDelegate {
        private let stored = Mutex<(source: Source, bytes: Int64?)>((.unknown, nil))

        var measurement: (source: Source, bytes: Int64?) { stored.withLock { $0 } }

        func urlSession(
            _ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics
        ) {
            guard metrics.transactionMetrics.count == 1, let transaction = metrics.transactionMetrics.first else { return }
            stored.withLock { measurement in
                switch transaction.resourceFetchType {
                case .networkLoad: measurement = (.network, transaction.countOfResponseBodyBytesReceived)
                case .localCache: measurement = (.urlCache, nil)
                default: break
                }
            }
        }

        func urlSession(
            _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }
}
#endif
