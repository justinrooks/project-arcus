import Foundation
import OSLog
import SwiftUI

protocol ForegroundActivityReporting: Sendable {
    func reportForegroundActivity() async
}

protocol ForegroundActivityUploading: Sendable {
    func upload(installationId: String) async throws
}

enum ForegroundActivityError: Error, Equatable {
    case invalidResponseStatus(Int)
}

actor ForegroundActivityReporter: ForegroundActivityReporting {
    static let shared = ForegroundActivityReporter()

    typealias InstallationIDProvider = @Sendable () async -> String

    private let uploader: any ForegroundActivityUploading
    private let installationIdProvider: InstallationIDProvider
    private let logger: Logger

    init(
        uploader: any ForegroundActivityUploading = HTTPForegroundActivityUploader(),
        installationIdProvider: @escaping InstallationIDProvider = {
            InstallationIdentityStore.shared.installationId()
        },
        logger: Logger = .appMain
    ) {
        self.uploader = uploader
        self.installationIdProvider = installationIdProvider
        self.logger = logger
    }

    func reportForegroundActivity() async {
        let installationId = await installationIdProvider()

        do {
            try await HTTPExecutionMode.$current.withValue(.foreground) {
                try await uploader.upload(installationId: installationId)
            }
            logger.debug("Foreground activity reported")
        } catch {
            // Do not persist a successful-send marker: a later foreground transition may retry.
            logger.error("Foreground activity report failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

actor HTTPForegroundActivityUploader: ForegroundActivityUploading {
    private struct RequestBody: Encodable {
        let installationId: String
    }

    private let consent: InstallationConsentStore
    private let endpoint: URL
    private let http: HTTPClient
    private let enrollment: InstallationEnrollmentCoordinator
    private let baseURL: URL
    private let encoder = JSONEncoder()

    init(baseURL: URL = ArcusSignalConfiguration.baseURL(), http: HTTPClient = URLSessionHTTPClient(),
        enrollment: InstallationEnrollmentCoordinator = .shared,
        consent: InstallationConsentStore = .shared) {
        guard let endpoint = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.foregroundActivityPath
        ) else {
            preconditionFailure("Invalid Arcus signal base URL")
        }
        self.consent = consent
        self.endpoint = endpoint
        self.http = http
        self.enrollment = enrollment
        self.baseURL = baseURL
    }

    func upload(installationId: String) async throws {
        let body = try encoder.encode(RequestBody(installationId: installationId))
        let credential = try await enrollment.credential(
            for: installationId, baseURL: baseURL, http: http
        )
        try await consent.synchronize(installationId: installationId, baseURL: baseURL,
                                      http: http, credential: credential)
        try Task.checkCancellation()
        var headers = requestHeaders
        headers["Authorization"] = "Bearer \(credential)"
        let response = try await http.post(endpoint, headers: headers, body: body)
        guard response.status == 204 else {
            throw ForegroundActivityError.invalidResponseStatus(response.status)
        }
    }

    private var requestHeaders: [String: String] {
        [
            "User-Agent": HTTPRequestHeaders.userAgent(),
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}

enum ForegroundActivityLifecycle {
    static func handleScenePhaseChange(
        _ scenePhase: ScenePhase,
        reporter: any ForegroundActivityReporting
    ) async {
        guard scenePhase == .active else { return }
        await reporter.reportForegroundActivity()
    }
}
