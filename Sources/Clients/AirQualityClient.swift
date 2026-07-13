import ArcusCore
import Foundation
import OSLog

struct AirQualityHTTPClient: AirQualityQuerying {
    private let http: HTTPClient
    private let baseURL: URL
    private let logger = Logger.providersArcusClient

    init(baseURL: URL = ArcusSignalConfiguration.baseURL(), http: HTTPClient = URLSessionHTTPClient()) {
        self.baseURL = baseURL
        self.http = http
    }

    func fetchCurrentAirQuality(h3Cell: Int64) async throws -> AirQualityCurrentResponse? {
        guard let url = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.airQualityCurrentPath,
            queryItems: [.init(name: "h3", value: String(h3Cell))]
        ) else {
            throw ArcusError.invalidUrl
        }

        let response = try await http.get(url, headers: HTTPRequestHeaders.arcus())
        switch response.classifyStatus() {
        case .success, .notModified:
            guard let data = response.data else { throw ArcusError.missingData }
            return try DecoderFactory.iso8601.decode(AirQualityCurrentResponse?.self, from: data)
        case .rateLimited(let retryAfter):
            throw ArcusError.rateLimited(retryAfterSeconds: retryAfter)
        case .serviceUnavailable(let retryAfter):
            throw ArcusError.serviceUnavailable(retryAfterSeconds: retryAfter)
        case .failure(let status):
            logger.error("Arcus AQI request failed endpoint=\(url.path, privacy: .public) status=\(status, privacy: .public)")
            throw ArcusError.networkError(status: status)
        }
    }
}
