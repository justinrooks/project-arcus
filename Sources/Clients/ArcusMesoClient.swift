import Foundation
import OSLog

protocol ArcusMesoClient: Sendable {
    func fetchActiveMesos(h3Cell: Int64?) async throws -> HTTPResponse
    func fetchMeso(productID: String) async throws -> HTTPResponse
}

struct ArcusMesoHTTPClient: ArcusMesoClient {
    private let http: HTTPClient
    private let baseURL: URL
    private let reachabilityReporter: any ArcusSignalReachabilityReporting
    private let logger = Logger.providersArcusClient
    private let fallbackPolicy: HTTPFallbackPolicy = .maximumAge(2 * 60)

    init(
        baseURL: URL = ArcusSignalConfiguration.baseURL(),
        http: HTTPClient = URLSessionHTTPClient(),
        reachabilityReporter: any ArcusSignalReachabilityReporting = NoOpArcusSignalReachabilityReporter()
    ) {
        self.baseURL = baseURL
        self.http = http
        self.reachabilityReporter = reachabilityReporter
    }

    func fetchActiveMesos(h3Cell: Int64?) async throws -> HTTPResponse {
        let queryItems = h3Cell.map { [URLQueryItem(name: "h3", value: String($0))] } ?? []
        return try await fetch(queryItems: queryItems)
    }

    func fetchMeso(productID: String) async throws -> HTTPResponse {
        try await fetch(queryItems: [URLQueryItem(name: "id", value: productID)])
    }

    private func fetch(queryItems: [URLQueryItem]) async throws -> HTTPResponse {
        guard let url = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.mesosPath,
            queryItems: queryItems
        ) else {
            throw ArcusError.invalidUrl
        }

        do {
            try Task.checkCancellation()
            let response = try await http.get(url, headers: HTTPRequestHeaders.arcus(), fallbackPolicy: fallbackPolicy)
            try Task.checkCancellation()

            if response.source != .live {
                logger.notice("Arcus response served from \(response.source.description, privacy: .public) endpoint=\(url.path, privacy: .public)")
            }

            switch response.classifyStatus() {
            case .success, .notModified:
                guard response.data != nil else { throw ArcusError.missingData }
                switch response.source {
                case .live, .cacheRevalidated304: await reachabilityReporter.markReachable()
                case .cacheFallback: await reachabilityReporter.markUnavailable()
                case .localCache: break
                }
                return response
            case .rateLimited(let retryAfter): throw ArcusError.rateLimited(retryAfterSeconds: retryAfter)
            case .serviceUnavailable(let retryAfter): throw ArcusError.serviceUnavailable(retryAfterSeconds: retryAfter)
            case .failure(let status): throw ArcusError.networkError(status: status)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await reachabilityReporter.markUnavailable()
            throw error
        }
    }
}
