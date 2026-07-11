//
//  StormSetupClient.swift
//  SkyAware
//
//  Created by Codex on 7/2/26.
//

import Foundation
import ArcusCore
import OSLog

struct StormSetupHTTPClient: StormSetupQuerying {
    private let http: HTTPClient
    private let baseURL: URL
    private let logger = Logger.providersArcusClient

    init(
        baseURL: URL = ArcusSignalConfiguration.baseURL(),
        http: HTTPClient = URLSessionHTTPClient()
    ) {
        self.baseURL = baseURL
        self.http = http
    }

    func fetchCurrentStormSetup(h3Cell: Int64) async throws -> StormSetupCurrentResponse {
        let url = try makeURL(
            queryItems: [
                URLQueryItem(name: "h3", value: canonicalH3String(for: h3Cell))
            ]
        )
        logger.info(
            "Arcus request started endpoint=\(url.path, privacy: .public) mode=\(HTTPExecutionMode.current.logName, privacy: .public) request=storm-setup-current"
        )

        return try await fetch(from: url)
    }

    private var requestHeaders: [String: String] {
        HTTPRequestHeaders.arcus()
    }

    private func canonicalH3String(for h3Cell: Int64) -> String {
        String(h3Cell)
    }

    private func fetch(from url: URL) async throws -> StormSetupCurrentResponse {
        do {
            try Task.checkCancellation()

            let httpResponse = try await http.get(url, headers: requestHeaders)
            try Task.checkCancellation()

            if httpResponse.source != .live {
                logger.notice("Arcus response served from \(httpResponse.source.description, privacy: .public) endpoint=\(url.path, privacy: .public)")
            }

            switch httpResponse.classifyStatus() {
            case .success, .notModified:
                guard let data = httpResponse.data else {
                    logger.error("Arcus response missing body endpoint=\(url.path, privacy: .public) status=\(httpResponse.status, privacy: .public)")
                    throw ArcusError.missingData
                }

                do {
                    let stormSetupResponse = try DecoderFactory.iso8601.decode(StormSetupCurrentResponse.self, from: data)
                    logger.info(
                        "Arcus request completed endpoint=\(url.path, privacy: .public) status=\(httpResponse.status, privacy: .public) source=\(httpResponse.source.description, privacy: .public) bytes=\(data.count, privacy: .public)"
                    )
                    return stormSetupResponse
                } catch {
                    logger.error("Arcus response decoding failed endpoint=\(url.path, privacy: .public) status=\(httpResponse.status, privacy: .public)")
                    throw ArcusError.parsingError
                }
            case .rateLimited(let retryAfter):
                let error = ArcusError.rateLimited(retryAfterSeconds: retryAfter)
                logFailure(error: error, endpoint: url.path, status: httpResponse.status)
                throw error
            case .serviceUnavailable(let retryAfter):
                let error = ArcusError.serviceUnavailable(retryAfterSeconds: retryAfter)
                logFailure(error: error, endpoint: url.path, status: httpResponse.status)
                throw error
            case .failure(let status):
                let error = ArcusError.networkError(status: status)
                logFailure(error: error, endpoint: url.path, status: status)
                throw error
            }
        } catch let error as CancellationError {
            throw error
        }
    }

    private func logFailure(error: ArcusError, endpoint: String, status: Int) {
        switch error {
        case .rateLimited(let retryAfter):
            logger.warning("Arcus rate limited endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
        case .serviceUnavailable(let retryAfter):
            logger.warning("Arcus service unavailable endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public) retryAfterSeconds=\(retryAfter ?? -1, privacy: .public)")
        default:
            logger.error("Arcus request failed endpoint=\(endpoint, privacy: .public) status=\(status, privacy: .public)")
        }
    }

    private func makeURL(queryItems: [URLQueryItem]) throws -> URL {
        guard let url = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.stormSetupCurrentPath,
            queryItems: queryItems
        ) else {
            throw ArcusError.invalidUrl
        }

        return url
    }
}
