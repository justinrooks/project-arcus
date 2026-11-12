import Foundation

/// Retrieval evidence only. Completeness does not establish publication coherence or an all-clear.
struct WSSIAcquisition: Sendable {
    let scope: WSSIScope
    let layers: [Layer]
    fileprivate let reusableResponses: [URL: HTTPResponse]

    struct Layer: Sendable {
        let id: Int
        let collection: WSSIFeatureCollection
        let requests: [Request]
    }

    struct Request: Sendable {
        let url: URL
        let receivedAt: Date
        let status: Int
        let headers: [String: String]
        let byteCount: Int
        let decodedByteCount: Int
    }
}

enum WSSIAcquisitionError: Error, Equatable {
    case invalidLimits
    case responseTooLarge
    case invalidResponse
    case httpStatus(Int)
    case incompleteInventory
    case featureLimit
    case unexpectedLayer
}

struct WSSIClient: Sendable {
    struct Limits: Sendable {
        var pageSize = 100
        var maximumFeaturesPerLayer = 2_000
        var maximumResponseBytes = 25_000_000
        var maximumTotalBytes = 100_000_000
        var requestTimeout: TimeInterval = 30
    }

    /// The transport must enforce the supplied byte ceiling while receiving, before decoding.
    typealias Transport = @Sendable (URLRequest, Int) async throws -> HTTPResponse
    private let transport: Transport
    private let limits: Limits
    private let endpoint = URL(string: "https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/wpc_wssi/MapServer")!

    init(limits: Limits = Limits(), transport: @escaping Transport = { try await WSSIClient.download($0, maximumBytes: $1) }) throws {
        guard (1...2_000).contains(limits.pageSize), limits.maximumFeaturesPerLayer > 0,
              limits.maximumResponseBytes > 0, limits.maximumTotalBytes > 0,
              limits.requestTimeout.isFinite, limits.requestTimeout > 0 else {
            throw WSSIAcquisitionError.invalidLimits
        }
        self.limits = limits
        self.transport = transport
    }

    /// Sequential requests bound concurrency to one. No cache fallback or automatic retries.
    func acquire(scope: WSSIScope, previous: WSSIAcquisition? = nil) async throws -> WSSIAcquisition {
        // Only a prior complete retrieval supplies reusable bodies; validators never identify a publication.
        let reusable = previous?.scope == scope ? previous?.reusableResponses ?? [:] : [:]
        var retained: [URL: HTTPResponse] = [:]
        var layers: [WSSIAcquisition.Layer] = []
        var totalBytes = 0
        for (product, firstID) in zip(WSSIProduct.allCases, [1, 6, 11, 16, 24]) {
            for (offset, period) in WSSIPeriod.allCases.enumerated() {
                let id = firstID + offset
                var requests: [WSSIAcquisition.Request] = []
                func fetch(_ parameters: [String: String]) async throws -> (Data, [String: Any]) {
                    try Task.checkCancellation()
                    var components = URLComponents(url: endpoint.appendingPathComponent("\(id)/query"),
                                                   resolvingAgainstBaseURL: false)!
                    let common = ["f": "json", "where": "1=1", "inSR": "4326", "outSR": "4326",
                                  "geometryType": "esriGeometryEnvelope", "spatialRel": "esriSpatialRelIntersects",
                                  "geometry": "\(scope.west),\(scope.south),\(scope.east),\(scope.north)"]
                    components.queryItems = common.merging(parameters) { _, new in new }.sorted { $0.key < $1.key }
                        .map { URLQueryItem(name: $0.key, value: $0.value) }
                    let url = components.url!
                    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                             timeoutInterval: limits.requestTimeout)
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    let cached = reusable[url]
                    if let etag = cached?.header("ETag") {
                        request.setValue(etag, forHTTPHeaderField: "If-None-Match")
                    }
                    let ceiling = min(limits.maximumResponseBytes, limits.maximumTotalBytes - totalBytes)
                    guard ceiling > 0 else { throw WSSIAcquisitionError.responseTooLarge }
                    let response = try await transport(request, ceiling)
                    try Task.checkCancellation()
                    guard response.status == 200 || response.status == 304 else {
                        throw WSSIAcquisitionError.httpStatus(response.status)
                    }
                    let data: Data
                    if response.status == 304 {
                        guard cached?.header("ETag") != nil, let body = cached?.data,
                              response.data?.isEmpty != false else { throw WSSIAcquisitionError.invalidResponse }
                        data = body
                    } else {
                        guard let body = response.data else { throw WSSIAcquisitionError.invalidResponse }
                        data = body
                    }
                    guard response.source == .live else {
                        throw WSSIAcquisitionError.invalidResponse
                    }
                    guard data.count <= ceiling else { throw WSSIAcquisitionError.responseTooLarge }
                    totalBytes += data.count
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          json["error"] == nil else { throw WSSIAcquisitionError.invalidResponse }
                    requests.append(.init(url: url, receivedAt: Date(), status: response.status,
                                          headers: response.headers, byteCount: response.data?.count ?? 0,
                                          decodedByteCount: data.count))
                    retained[url] = HTTPResponse(status: 200, headers: response.status == 304
                        ? ["ETag": response.header("ETag") ?? cached?.header("ETag") ?? ""] : response.headers, data: data)
                    return (data, json)
                }
                func inventory() async throws -> Set<Int> {
                    let (_, json) = try await fetch(["returnIdsOnly": "true"])
                    guard json["objectIdFieldName"] as? String == "objectid",
                          json["objectIds"] is [Any] || json["objectIds"] is NSNull,
                          json["exceededTransferLimit"] as? Bool != true else {
                        throw WSSIAcquisitionError.incompleteInventory
                    }
                    let ids = try (json["objectIds"] as? [Any] ?? []).map { try Self.objectID($0) }
                    guard ids.count <= limits.maximumFeaturesPerLayer else { throw WSSIAcquisitionError.featureLimit }
                    guard Set(ids).count == ids.count else { throw WSSIAcquisitionError.incompleteInventory }
                    return Set(ids)
                }
                let expected = try await inventory()
                var seen = Set<Int>()
                var features: [WSSIFeature] = []
                // Fetch even the empty page: validate source feature-set structure independently of the inventory.
                repeat {
                    let (data, json) = try await fetch([
                        "outFields": "*", "returnGeometry": "true", "orderByFields": "objectid ASC",
                        "resultOffset": "\(seen.count)", "resultRecordCount": "\(limits.pageSize)"
                    ])
                    guard let raw = json["features"] as? [[String: Any]], raw.count <= limits.pageSize else {
                        throw WSSIAcquisitionError.incompleteInventory
                    }
                    let ids = try raw.map { feature in
                        guard let attributes = feature["attributes"] as? [String: Any],
                              let value = attributes["objectid"] else { throw WSSIAcquisitionError.incompleteInventory }
                        return try Self.objectID(value)
                    }
                    guard Set(ids).count == ids.count, seen.isDisjoint(with: ids),
                          Set(ids).isSubset(of: expected), !ids.isEmpty || expected.isEmpty else {
                        throw WSSIAcquisitionError.incompleteInventory
                    }
                    seen.formUnion(ids)
                    let decoded = try WSSIDecoder.decode(data)
                    guard decoded.features.allSatisfy({ $0.product == product && $0.period == period }) else {
                        throw WSSIAcquisitionError.unexpectedLayer
                    }
                    features.append(contentsOf: decoded.features)
                    let more = json["exceededTransferLimit"] as? Bool == true
                    guard more == (seen.count < expected.count) else { throw WSSIAcquisitionError.incompleteInventory }
                } while seen.count < expected.count
                guard seen == expected, try await inventory() == expected else {
                    throw WSSIAcquisitionError.incompleteInventory
                }
                layers.append(.init(id: id, collection: .init(features: features), requests: requests))
            }
        }
        try Task.checkCancellation()
        return WSSIAcquisition(scope: scope, layers: layers, reusableResponses: retained)
    }

    private static func objectID(_ value: Any) throws -> Int {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
              number.doubleValue >= 0, number.doubleValue < Double(Int.max) else {
            throw WSSIAcquisitionError.incompleteInventory
        }
        return number.intValue
    }

    static func download(_ request: URLRequest, maximumBytes: Int,
                         configuration: URLSessionConfiguration = .ephemeral) async throws -> HTTPResponse {
        configuration.timeoutIntervalForResource = request.timeoutInterval
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw WSSIAcquisitionError.invalidResponse }
        guard http.statusCode == 200 || http.statusCode == 304 else { throw WSSIAcquisitionError.httpStatus(http.statusCode) }
        guard response.expectedContentLength <= Int64(maximumBytes) else {
            throw WSSIAcquisitionError.responseTooLarge
        }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maximumBytes else { throw WSSIAcquisitionError.responseTooLarge }
            data.append(byte)
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) {
            $0[String(describing: $1.key)] = String(describing: $1.value)
        }
        return HTTPResponse(status: http.statusCode, headers: headers, data: data)
    }
}
