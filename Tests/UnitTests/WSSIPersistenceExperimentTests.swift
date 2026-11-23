#if DEBUG
import Foundation
import Testing
@testable import SkyAware

struct WSSIPersistenceExperimentTests {
    @Test func savesReopensAndReplacesFullCapture() async throws {
        let parent = try makeParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let report = try await WSSIPersistenceExperiment(temporaryDirectory: parent).run(fixture: fixture())
        try expectOnlySentinel(in: parent)
        #expect(report.fixture == "overall-1.geojson")
        #expect(report.metadata.product == "Overall_Impact")
        #expect(report.metadata.day == 1)
        #expect(report.metadata.revision.uuidString.lowercased() == "8afb87e2-451c-431c-8b0d-e18ea577ce0d")
        #expect(report.replacementRevisions.map { $0.uuidString.lowercased() } == [
            "8afb87e2-451c-431c-8b0d-e18ea577ce0c",
            "8afb87e2-451c-431c-8b0d-e18ea577ce0f",
            "8afb87e2-451c-431c-8b0d-e18ea577ce0e"
        ])
        #expect(report.retainedPayloadBytes == 2_205_798)
        #expect(report.samples.map(\.stage) == [
            "empty store", "insert + save", "initial fetch",
            "reopen 1", "fetch 1", "replace 1 + save",
            "reopen 2", "fetch 2", "replace 2 + save",
            "reopen 3", "fetch 3", "replace 3 + save", "reopen 4", "fetch 4"
        ])
        let rows = report.samples.map {
            "\($0.stage) | \($0.elapsed) | \($0.databaseAllocatedBytes) | \($0.walAllocatedBytes) | \(bytes($0.footprintBytes))"
        }
        let observation = [
            "Simulator only. Fixture: \(report.fixture), revision: \(report.metadata.revision).",
            "Synthetic replacements: \(report.replacementRevisions.map(\.uuidString).joined(separator: ", ")).",
            "Logical geometry retained: \(report.retainedPayloadBytes) bytes.",
            "Sampled process footprint before load: \(bytes(report.footprintBeforeLoad)); after release: \(bytes(report.footprintAfterRelease)).",
            "Stage | Duration | SQLite allocated bytes | WAL allocated bytes | Sampled footprint bytes"
        ] + rows
        Attachment.record(observation.joined(separator: "\n"), named: "WSSI persistence simulator observation.txt")
    }

    @Test func replacementFailureRollsBackAndThrows() async throws {
        let url = try fixture()
        let parent = try makeParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        await #expect(throws: WSSIPersistenceExperiment.Failure.injectedBeforeReplacementSave) {
            try await WSSIPersistenceExperiment(temporaryDirectory: parent).run(fixture: url, injectFailure: true)
        }
        try expectOnlySentinel(in: parent)
    }

    @Test func cancellationThrowsInsteadOfReportingSuccess() async throws {
        let url = try fixture()
        let attempt = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await WSSIPersistenceExperiment().run(fixture: url)
        }
        await #expect(throws: CancellationError.self) { try await attempt.value }
    }

    private func makeParent() throws -> URL {
        let files = FileManager.default
        let parent = files.temporaryDirectory.appending(path: "wssi-persistence-tests-\(UUID())")
        try files.createDirectory(at: parent, withIntermediateDirectories: false)
        do {
            try Data("keep".utf8).write(to: parent.appending(path: "sentinel"))
        } catch {
            try files.removeItem(at: parent)
            throw error
        }
        return parent
    }

    private func expectOnlySentinel(in parent: URL) throws {
        #expect(try FileManager.default.contentsOfDirectory(atPath: parent.path) == ["sentinel"])
        #expect(try Data(contentsOf: parent.appending(path: "sentinel")) == Data("keep".utf8))
    }

    private func fixture() throws -> URL {
        try #require(Bundle(for: WSSIPersistenceFixtureLocator.self).url(forResource: "overall-1", withExtension: "geojson"))
    }

    private func bytes(_ value: UInt64?) -> String {
        value.map(String.init) ?? "unavailable"
    }
}

private final class WSSIPersistenceFixtureLocator: NSObject {}
#endif
