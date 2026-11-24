import Foundation

/// Fetches Forge representations and leaves decoding and acceptance to the sync owner.
struct ForgeWSSIClient: Sendable {
    struct Response: Sendable {
        enum Outcome: Sendable, Equatable {
            case body(Data)
            case notModified(cachedBody: Data?)
        }

        let path: String
        let eTag: String?
        let outcome: Outcome
    }

    enum Error: Swift.Error, Equatable {
        case invalidOrigin
        case invalidGeometryPath
        case invalidValidator
        case invalidNotModified
        case missingBody
        case unexpectedResponseSource
        case httpStatus(Int, retryAfterSeconds: Int?)
    }

    private let origin: URL
    private let http: any HTTPClient

    // The accepted store owns WSSI payloads. Avoid retaining a second set in the transport cache.
    init(
        origin: URL,
        http: any HTTPClient = URLSessionHTTPClient(urlCache: URLCache(memoryCapacity: 0, diskCapacity: 0))
    ) {
        self.origin = origin
        self.http = http
    }

    // Passing nil requests a fresh body. The caller owns any recovery attempt after a 304.
    func fetchManifest(ifNoneMatch: String? = nil) async throws -> Response {
        try await fetch(path: "/v1/wssi/manifest", ifNoneMatch: ifNoneMatch, headers: HTTPRequestHeaders.arcus())
    }

    func fetchGeometry(for entry: WSSIManifestEntry, ifNoneMatch: String? = nil) async throws -> Response {
        guard let path = entry.canonicalGeometryPath else { throw Error.invalidGeometryPath }
        return try await fetch(path: path, ifNoneMatch: ifNoneMatch, headers: HTTPRequestHeaders.nws())
    }

    private func fetch(path: String, ifNoneMatch: String?, headers: [String: String]) async throws -> Response {
        try Task.checkCancellation()
        guard var url = ArcusForgeConfiguration.originComponents(for: origin) else {
            throw Error.invalidOrigin
        }
        url.path = path
        guard let requestURL = url.url else { throw Error.invalidOrigin }

        var requestHeaders = headers
        let tag: Data?
        if let ifNoneMatch {
            guard let value = HTTPETag.opaqueValue(ifNoneMatch) else { throw Error.invalidValidator }
            tag = value
            requestHeaders["If-None-Match"] = ifNoneMatch
        } else {
            tag = nil
        }
        let response = try await http.get(requestURL, headers: requestHeaders, fallbackPolicy: .explicitRevalidation)
        try Task.checkCancellation()

        let eTag = response.header("ETag")
        switch response.status {
        case 200:
            guard response.source == .live else { throw Error.unexpectedResponseSource }
            guard let body = response.data, !body.isEmpty else { throw Error.missingBody }
            let validatedETag = eTag.flatMap { HTTPETag.opaqueValue($0) == nil ? nil : $0 }
            return Response(path: path, eTag: validatedETag, outcome: .body(body))
        case 304:
            guard let tag,
                  eTag.map({ HTTPETag.opaqueValue($0) == tag }) ?? true else {
                throw Error.invalidNotModified
            }
            guard response.source.isNetworkBacked else { throw Error.unexpectedResponseSource }
            let cachedBody = response.source == .cacheRevalidated304 ? response.data : nil
            return Response(path: path, eTag: eTag, outcome: .notModified(cachedBody: cachedBody))
        default:
            throw Error.httpStatus(response.status, retryAfterSeconds: HTTPRetryAfterParser.seconds(from: response.header("Retry-After")))
        }
    }
}

extension WSSIManifestEntry {
    /// A usable manifest can address every advertised immutable revision.
    var canonicalGeometryPath: String? {
        guard let accepted, (1...3).contains(day) else { return nil }
        let revision = accepted.revision.uuidString.lowercased()
        let path = "/v1/wssi/\(product.rawValue)/days/\(day)/revisions/\(revision)/geometry"
        return accepted.geometryPath == path ? path : nil
    }
}
