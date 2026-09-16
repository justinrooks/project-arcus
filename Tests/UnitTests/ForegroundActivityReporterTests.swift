import Foundation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("Foreground Activity Reporter")
struct ForegroundActivityReporterTests {
    private enum TestError: Error {
        case unavailable
    }

    private actor RecordingUploader: ForegroundActivityUploading {
        private var results: [Result<Void, TestError>]
        private var installationIds: [String] = []

        init(results: [Result<Void, TestError>]) {
            self.results = results
        }

        func upload(installationId: String) async throws {
            installationIds.append(installationId)
            try results.removeFirst().get()
        }

        func uploadedInstallationIds() -> [String] {
            installationIds
        }
    }

    private actor RecordingReporter: ForegroundActivityReporting {
        private var reportCount = 0

        func reportForegroundActivity() async {
            reportCount += 1
        }

        func count() -> Int {
            reportCount
        }
    }

    @Test("reporter uses the stable installation ID and retries on a later foreground opportunity after failure")
    func reporterUsesInstallationIdAndDoesNotSuppressRetryAfterFailure() async {
        let uploader = RecordingUploader(results: [.failure(.unavailable), .success(())])
        let reporter = ForegroundActivityReporter(
            uploader: uploader,
            installationIdProvider: { "f0465f55-f0a2-48a0-aac0-6a5c48a95891" }
        )

        await reporter.reportForegroundActivity()
        await reporter.reportForegroundActivity()

        #expect(
            await uploader.uploadedInstallationIds()
                == ["f0465f55-f0a2-48a0-aac0-6a5c48a95891", "f0465f55-f0a2-48a0-aac0-6a5c48a95891"]
        )
    }

    @Test("only an active scene transition reports foreground activity")
    func lifecycleReportsOnlyForActiveScene() async {
        let reporter = RecordingReporter()

        await ForegroundActivityLifecycle.handleScenePhaseChange(.background, reporter: reporter)
        await ForegroundActivityLifecycle.handleScenePhaseChange(.inactive, reporter: reporter)
        await ForegroundActivityLifecycle.handleScenePhaseChange(.active, reporter: reporter)

        #expect(await reporter.count() == 1)
    }
}

@Suite("HTTP Foreground Activity Uploader")
struct HTTPForegroundActivityUploaderTests {
    @Test("upload sends only the installation ID to the foreground activity endpoint")
    func uploadSendsMinimalRequest() async throws {
        let http = ForegroundActivityMockHTTPClient(response: HTTPResponse(status: 202, headers: [:], data: nil))
        let uploader = HTTPForegroundActivityUploader(
            baseURL: URL(string: "https://arcus.example.com")!,
            http: http
        )

        try await uploader.upload(installationId: "f0465f55-f0a2-48a0-aac0-6a5c48a95891")

        let request = try #require(await http.firstRequest())
        #expect(request.method == "POST")
        #expect(request.url.path == ArcusSignalConfiguration.foregroundActivityPath)
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Content-Type"] == "application/json")

        let body = try #require(request.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["installationId": "f0465f55-f0a2-48a0-aac0-6a5c48a95891"])
    }

    @Test("reporting runs with the foreground HTTP policy")
    func reporterUsesForegroundHTTPPolicy() async {
        let uploader = ExecutionModeRecordingUploader()
        let reporter = ForegroundActivityReporter(
            uploader: uploader,
            installationIdProvider: { "f0465f55-f0a2-48a0-aac0-6a5c48a95891" }
        )

        await reporter.reportForegroundActivity()

        #expect(await uploader.executionMode() == .foreground)
    }
}

private actor ExecutionModeRecordingUploader: ForegroundActivityUploading {
    private var mode: HTTPExecutionMode?

    func upload(installationId: String) async throws {
        mode = HTTPExecutionMode.current
    }

    func executionMode() -> HTTPExecutionMode? {
        mode
    }
}

private actor ForegroundActivityMockHTTPClientState {
    var request: (method: String, url: URL, headers: [String: String], body: Data?)?

    func record(method: String, url: URL, headers: [String: String], body: Data?) {
        request = (method: method, url: url, headers: headers, body: body)
    }
}

private final class ForegroundActivityMockHTTPClient: HTTPClient, @unchecked Sendable {
    private let state = ForegroundActivityMockHTTPClientState()
    private let response: HTTPResponse

    init(response: HTTPResponse) {
        self.response = response
    }

    func get(_ url: URL, headers: [String: String]) async throws -> HTTPResponse {
        response
    }

    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        await state.record(method: "POST", url: url, headers: headers, body: body)
        return response
    }

    func clearCache() {}

    func firstRequest() async -> (method: String, url: URL, headers: [String: String], body: Data?)? {
        await state.request
    }
}
