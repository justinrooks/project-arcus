#if DEBUG
import Foundation
import Testing
@testable import SkyAware

private final class ProbeFixtureLocator {}
private actor RetryCounter {
    var count = 0
    func next() -> Int { count += 1; return count }
}
private actor ProbeRows {
    var rows: [WSSIProbeRow] = []
    func add(_ items: [WSSIProbeRow]) { rows.append(contentsOf: items) }
}

@MainActor
struct WSSIProbeModelTests {
    @Test func restoresInterruptedRunAndResets() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "wssi-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let original = WSSIProbeRecord(status: "running: decode completed", rows: [.init(stage: "decode", metric: "seconds", value: "1")])
        try JSONEncoder().encode(original).write(to: file, options: .atomic)
        let model = WSSIProbeModel(recordURL: file)
        #expect(model.record?.status == "interrupted: running: decode completed")
        #expect(model.record?.rows == original.rows)
        model.reset()
        #expect(model.record == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func invalidOriginShowsFailureAndAllowsReset() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "wssi-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let model = WSSIProbeModel(recordURL: file)
        model.origin = "https://user:secret@forge.example/?token=secret"
        model.start()
        #expect(model.record?.status == "failed: enter a valid HTTP(S) Forge origin")
        #expect(!model.running)
        let saved = try String(contentsOf: file, encoding: .utf8)
        #expect(!saved.contains("secret"))
        model.reset()
        #expect(model.record == nil)
    }

    @Test func runCompletesWithSelectedModeAndObservations() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "wssi-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let model = WSSIProbeModel(recordURL: file) { _, slot, mode, _, update in
            await update("download", [.init(stage: "test", metric: slot.product, value: mode.rawValue)])
        }
        model.mode = .persistence
        model.origin = "https://forge.example"
        model.start()
        while model.running { await Task.yield() }
        #expect(model.record?.status == "completed")
        #expect(model.record?.rows.contains(.init(stage: "test", metric: "Overall_Impact", value: "Download + decode + persistence")) == true)
    }

    @Test func cancellationRetainsPartialResultsAndPreventsOverlap() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "wssi-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let model = WSSIProbeModel(recordURL: file) { _, _, _, _, update in
            await update("download", [.init(stage: "download", metric: "body", value: "received")])
            try await Task.sleep(for: .seconds(30))
        }
        model.origin = "https://forge.example"
        model.start()
        while model.record?.rows.contains(where: { $0.metric == "body" }) != true { await Task.yield() }
        model.start()
        model.cancel()
        while model.running { await Task.yield() }
        #expect(model.record?.status == "cancelled")
        #expect(model.record?.rows.filter { $0.metric == "body" }.count == 1)
    }

    @Test func runnerFailureIsVisibleAndRetryable() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "wssi-test-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let counter = RetryCounter()
        let model = WSSIProbeModel(recordURL: file) { _, _, _, _, _ in
            if await counter.next() == 1 { throw WSSIProbeWorker.ProbeError.noGeometry("unavailable") }
        }
        model.origin = "https://forge.example"
        model.start()
        while model.running { await Task.yield() }
        #expect(model.record?.status == "failed: unavailable")
        model.origin = "https://forge.example"
        model.start()
        while model.running { await Task.yield() }
        #expect(model.record?.status == "completed")
        #expect(await counter.count == 2)
    }

    @Test(arguments: WSSIProbeWorker.Mode.allCases)
    func modesUseRealFixtureAndEmitExpectedStages(mode: WSSIProbeWorker.Mode) async throws {
        let fixture = try #require(Bundle(for: ProbeFixtureLocator.self).url(forResource: "overall-1", withExtension: "geojson"))
        let body = try Data(contentsOf: fixture)
        let metadata = try JSONDecoder().decode(WSSIGeometryExperiment.Collection.self, from: body).metadata
        let path = "/v1/wssi/Overall_Impact/days/1/revisions/\(metadata.revision.uuidString.lowercased())/geometry"
        let datasets = ["Overall_Impact", "Snow_Amount", "Snow_Load", "Ice_Accumulation", "Blowing_Snow"].flatMap { product in
            (1...3).map { day in
                let accepted: WSSIAcquisitionProbe.Revision? = product == "Overall_Impact" && day == 1
                    ? .init(revision: metadata.revision, issuedAt: "test", validFrom: "test", validTo: "test", gisFileDate: nil, gisIngestDate: nil, retrievedAt: "test", geometryPath: path) : nil
                return WSSIAcquisitionProbe.Dataset(product: product, day: day, validity: "valid", sourceStatus: "available", coverage: "unknown", accepted: accepted)
            }
        }
        let manifest = try JSONEncoder().encode(["datasets": datasets])
        let scratch = FileManager.default.temporaryDirectory.appending(path: "wssi-test-scratch-\(UUID())")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let worker = WSSIProbeWorker(transport: { request in
            let data = request.url?.path == "/v1/wssi/manifest" ? manifest : body
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return .init(body: data, response: response, source: .network, networkBodyBytes: Int64(data.count))
        }, scratch: scratch)
        let rows = ProbeRows()
        try await worker.run(origin: try #require(URL(string: "https://forge.example")), slot: .overallDayOne, mode: mode,
                             environment: .init(device: "simulator", runtime: "test", build: "test")) { _, items in await rows.add(items) }
        let values = await rows.rows
        #expect(values.contains { $0.metric == "revision" && $0.value.lowercased() == metadata.revision.uuidString.lowercased() })
        #expect(values.contains { $0.stage == "coldGeometry" && $0.metric == "http_status" && $0.value == "200" })
        #expect(values.contains { $0.stage == "decode" && $0.metric == "seconds" } == (mode != .download))
        #expect(values.contains { $0.stage == "assessment" && $0.metric == "matching_severities" } == (mode != .download))
        if mode != .download {
            #expect(values.contains { $0.metric == "matching_severities" && $0.value == "WinterWeatherArea|Minor|Moderate|Major|Extreme;WinterWeatherArea|Minor|Moderate;" })
        }
        #expect(values.contains { $0.stage == "persistence" && $0.metric == "logical_payload_bytes" } == (mode == .persistence))
        if mode == .download {
            let file = FileManager.default.temporaryDirectory.appending(path: "wssi-checkpoint-\(UUID()).json")
            defer { try? FileManager.default.removeItem(at: file) }
            let gated = WSSIProbeWorker(transport: { request in
                if request.url?.path != "/v1/wssi/manifest" { try await Task.sleep(for: .seconds(30)) }
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return .init(body: manifest, response: response, source: .network, networkBodyBytes: Int64(manifest.count))
            }, scratch: scratch)
            let model = WSSIProbeModel(recordURL: file) { origin, slot, mode, environment, update in
                try await gated.run(origin: origin, slot: slot, mode: mode, environment: environment, update: update)
            }
            model.origin = "https://forge.example"
            model.start()
            while model.record?.rows.contains(where: { $0.metric == "revision" }) != true { await Task.yield() }
            model.cancel()
            while model.running { await Task.yield() }
            let restored = WSSIProbeModel(recordURL: file)
            #expect(restored.record?.status == "cancelled")
            #expect(restored.record?.rows.filter { $0.stage == "manifest" && $0.metric == "http_status" }.count == 1)
            #expect(restored.record?.rows.filter { $0.metric == "revision" }.count == 1)
            #expect(restored.record?.rows.contains { $0.stage == "coldGeometry" || $0.stage == "decode" } == false)
        }
    }

    @Test func exportEscapesFieldsAndKeepsMissingValuesExplicit() {
        let record = WSSIProbeRecord(status: "completed", rows: [.init(stage: "transfer", metric: "etag", value: "\"abc,def\""), .init(stage: "transfer", metric: "bytes", value: "not measured")])
        let csv = WSSIProbeExport(record: record).csv
        #expect(csv.contains("\"\"\"abc,def\"\"\""))
        #expect(csv.contains("\"not measured\""))
    }
}
#endif
