#if DEBUG
import Darwin
import CoreLocation
import CoreTransferable
import Foundation
import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct WSSIProbeRow: Codable, Sendable, Equatable {
    let stage: String
    let metric: String
    let value: String
}

struct WSSIProbeRecord: Codable, Sendable {
    var status: String
    var rows: [WSSIProbeRow]
}

struct WSSIProbeExport: Transferable {
    let record: WSSIProbeRecord
    var csv: String {
        func escaped(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return (["stage,metric,value"] + ([WSSIProbeRow(stage: "run", metric: "status", value: record.status)] + record.rows)
            .map { [ $0.stage, $0.metric, $0.value ].map(escaped).joined(separator: ",") }).joined(separator: "\n") + "\n"
    }
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { Data($0.csv.utf8) }
            .suggestedFileName("wssi-geometry-probe.csv")
    }
}

actor WSSIProbeWorker {
    enum Mode: String, CaseIterable, Sendable {
        case download = "Download only"
        case decode = "Download + decode"
        case persistence = "Download + decode + persistence"
    }
    typealias Update = @Sendable (String, [WSSIProbeRow]) async -> Void
    private let transport: WSSIAcquisitionProbe.Transport?
    private let scratch: URL
    init(transport: WSSIAcquisitionProbe.Transport? = nil,
         scratch: URL = FileManager.default.temporaryDirectory.appending(path: "wssi-probe-scratch", directoryHint: .isDirectory)) {
        self.transport = transport
        self.scratch = scratch
    }

    func run(origin: URL, slot: WSSIAcquisitionProbe.Slot, mode: Mode,
             environment: WSSIAcquisitionProbe.Environment, update: Update) async throws {
        let result = try await WSSIAcquisitionProbe(origin: origin, transport: transport).run(slot: slot, environment: environment) { report in
            await update("acquisition", Self.acquisitionRows(report, slot: slot))
        }
        let finalRequest = result.report.requests.last
        let bodySource: String
        if finalRequest?.outcome == .cacheRevalidated { bodySource = "revalidated cache" }
        else if finalRequest?.stage == .conditionalGeometry && finalRequest?.outcome == .body { bodySource = "conditional response" }
        else { bodySource = "cold response" }
        await update("acquisition", Self.acquisitionRows(result.report, slot: slot) + [
            .init(stage: "dataset", metric: "retained_body_bytes", value: result.geometry.map { String($0.count) } ?? "not available"),
            .init(stage: "dataset", metric: "retained_body_source", value: result.geometry == nil ? "not available" : bodySource)])
        guard let body = result.geometry else { throw ProbeError.noGeometry(result.report.stop?.rawValue ?? "no usable geometry") }
        try Task.checkCancellation()
        guard mode != .download else { return }
        await update("decode started", [])
        try Task.checkCancellation()
        let points = [CLLocationCoordinate2D(latitude: 46.85, longitude: -121.72),
                      CLLocationCoordinate2D(latitude: 46.87098, longitude: -121.75517),
                      CLLocationCoordinate2D(latitude: 44.9778, longitude: -93.2650)]
        let report = try WSSIGeometryExperiment.measure(body, fixtureIdentity: "downloaded revision", points: points)
        await update("decode", [WSSIProbeRow(stage: "decode", metric: "seconds", value: String(report.decodeSeconds)),
            WSSIProbeRow(stage: "decode", metric: "features", value: String(report.featureCount)),
            WSSIProbeRow(stage: "decode", metric: "vertices", value: String(report.vertexCount)),
            WSSIProbeRow(stage: "decode", metric: "sampled_footprint_before_bytes", value: report.footprintBeforeDecode.map(String.init) ?? "not measured"),
            WSSIProbeRow(stage: "decode", metric: "sampled_footprint_with_geometry_bytes", value: report.footprintWithGeometry.map(String.init) ?? "not measured"),
            WSSIProbeRow(stage: "decode", metric: "sampled_footprint_after_release_bytes", value: report.footprintAfterGeometryRelease.map(String.init) ?? "not measured"),
            WSSIProbeRow(stage: "assessment", metric: "seconds", value: String(report.containmentSeconds)),
            WSSIProbeRow(stage: "assessment", metric: "points_lat_lon", value: "46.85,-121.72;46.87098,-121.75517;44.9778,-93.2650"),
            WSSIProbeRow(stage: "assessment", metric: "matching_severities", value: report.matchingSeverities.map { $0.joined(separator: "|") }.joined(separator: ";"))])
        try Task.checkCancellation()
        guard mode == .persistence else { return }
        await update("persistence started", [])
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath: scratch.path) { try FileManager.default.removeItem(at: scratch) }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let file = scratch.appending(path: "input.geojson")
        try body.write(to: file, options: .atomic)
        let stored = try await WSSIPersistenceExperiment(temporaryDirectory: scratch).run(fixture: file)
        var rows = [WSSIProbeRow(stage: "persistence", metric: "logical_payload_bytes", value: String(stored.retainedPayloadBytes)),
                    WSSIProbeRow(stage: "persistence", metric: "sampled_footprint_before_load_bytes", value: stored.footprintBeforeLoad.map(String.init) ?? "not measured"),
                    WSSIProbeRow(stage: "persistence", metric: "sampled_footprint_after_release_bytes", value: stored.footprintAfterRelease.map(String.init) ?? "not measured")]
        rows += stored.samples.flatMap { sample in
            let parts = sample.elapsed.components
            let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
            return [WSSIProbeRow(stage: sample.stage, metric: "seconds", value: String(seconds)),
                    WSSIProbeRow(stage: sample.stage, metric: "database_allocated_bytes", value: String(sample.databaseAllocatedBytes)),
                    WSSIProbeRow(stage: sample.stage, metric: "wal_allocated_bytes", value: String(sample.walAllocatedBytes)),
                    WSSIProbeRow(stage: sample.stage, metric: "sampled_footprint_bytes", value: sample.footprintBytes.map(String.init) ?? "not measured")]
        }
        await update("persistence", rows)
    }
    private static func acquisitionRows(_ report: WSSIAcquisitionProbe.Report, slot: WSSIAcquisitionProbe.Slot) -> [WSSIProbeRow] {
        var rows = report.requests.flatMap { request in
            [WSSIProbeRow(stage: request.stage.rawValue, metric: "http_status", value: request.status.map(String.init) ?? "not measured"),
             WSSIProbeRow(stage: request.stage.rawValue, metric: "disposition", value: "\(request.outcome.rawValue) / \(request.source.rawValue)"),
             WSSIProbeRow(stage: request.stage.rawValue, metric: "elapsed_seconds", value: String(request.elapsedSeconds)),
             WSSIProbeRow(stage: request.stage.rawValue, metric: "network_body_bytes", value: request.networkBodyBytes.map(String.init) ?? "not measured"),
             WSSIProbeRow(stage: request.stage.rawValue, metric: "response_body_bytes", value: request.responseBodyBytes.map(String.init) ?? "not measured"),
             WSSIProbeRow(stage: request.stage.rawValue, metric: "reused_cache_body_bytes", value: request.reusedCacheBodyBytes.map(String.init) ?? "not measured"),
             WSSIProbeRow(stage: request.stage.rawValue, metric: "etag", value: request.etag ?? "not available")]
        }
        if let dataset = report.datasets.first(where: { $0.slot == slot }) {
            rows += [WSSIProbeRow(stage: "dataset", metric: "coverage", value: dataset.coverage),
                     WSSIProbeRow(stage: "dataset", metric: "validity", value: dataset.validity),
                     WSSIProbeRow(stage: "dataset", metric: "source_status", value: dataset.sourceStatus),
                     WSSIProbeRow(stage: "dataset", metric: "revision", value: dataset.accepted?.revision.uuidString ?? "not available")]
        }
        return rows
    }
    enum ProbeError: LocalizedError {
        case noGeometry(String)
        var errorDescription: String? { if case .noGeometry(let reason) = self { return reason }; return nil }
    }
}

@MainActor @Observable
final class WSSIProbeModel {
    static let shared = WSSIProbeModel()
    var origin = ""
    var network = ""
    var pass = ""
    var product = "Overall_Impact"
    var day = 1
    var mode: WSSIProbeWorker.Mode = .download
    private(set) var record: WSSIProbeRecord?
    private(set) var running = false
    private var task: Task<Void, Never>?
    private let recordURL: URL
    typealias Runner = @Sendable (URL, WSSIAcquisitionProbe.Slot, WSSIProbeWorker.Mode,
                                  WSSIAcquisitionProbe.Environment, @escaping WSSIProbeWorker.Update) async throws -> Void
    private let runner: Runner

    init(recordURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "wssi-probe-last-run.json"), runner: Runner? = nil) {
        self.recordURL = recordURL
        let worker = WSSIProbeWorker()
        self.runner = runner ?? { origin, slot, mode, environment, update in
            try await worker.run(origin: origin, slot: slot, mode: mode, environment: environment, update: update)
        }
        if let data = try? Data(contentsOf: recordURL), var saved = try? JSONDecoder().decode(WSSIProbeRecord.self, from: data) {
            if saved.status.hasPrefix("running:") { saved.status = "interrupted: " + saved.status }
            record = saved
        }
    }
    private static var deviceIdentity: String {
        var info = utsname()
        uname(&info)
        let size = MemoryLayout.size(ofValue: info.machine)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: size) { String(cString: $0) }
        }
#if targetEnvironment(simulator)
        return "simulator: \(ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine)"
#else
        return "device: \(machine)"
#endif
    }
    func start() {
        guard !running else { return }
        guard let url = URL(string: origin), WSSIAcquisitionProbe.validatedOrigin(url) != nil else {
            record = WSSIProbeRecord(status: "failed: enter a valid HTTP(S) Forge origin", rows: [])
            save()
            return
        }
        let environment = WSSIAcquisitionProbe.Environment(device: Self.deviceIdentity, runtime: UIDevice.current.systemVersion,
                                                            build: Bundle.main.fullVersion)
        let slot = WSSIAcquisitionProbe.Slot(product: product, day: day)
        let selectedMode = mode
        record = WSSIProbeRecord(status: "running: download", rows: [
            .init(stage: "run", metric: "started_at_utc", value: ISO8601DateFormatter().string(from: .now)),
            .init(stage: "run", metric: "device", value: environment.device), .init(stage: "run", metric: "os", value: environment.runtime),
            .init(stage: "run", metric: "build", value: environment.build), .init(stage: "run", metric: "network_reported", value: network.isEmpty ? "not provided" : network),
            .init(stage: "run", metric: "origin", value: origin), .init(stage: "run", metric: "dataset", value: "\(product) day \(day)"),
            .init(stage: "run", metric: "pass", value: pass.isEmpty ? "not provided" : pass), .init(stage: "run", metric: "mode", value: mode.rawValue), .init(stage: "run", metric: "fixture", value: "live downloaded revision")])
        running = true
        save()
        task = Task {
            do {
                try await runner(url, slot, selectedMode, environment) { [weak self] stage, rows in
                    await self?.update(stage: stage, rows: rows)
                }
                try Task.checkCancellation()
                finish("completed")
            } catch is CancellationError { finish("cancelled") }
            catch { finish(Task.isCancelled ? "cancelled" : "failed: \(error.localizedDescription)") }
        }
    }
    func cancel() { task?.cancel() }
    func reset() { guard !running else { return }; record = nil; try? FileManager.default.removeItem(at: recordURL) }
    private func update(stage: String, rows: [WSSIProbeRow]) {
        if stage == "acquisition" {
            record?.rows.removeAll { ["manifest", "coldGeometry", "conditionalGeometry", "dataset"].contains($0.stage) }
        }
        record?.rows.append(contentsOf: rows)
        record?.status = "running: \(stage)"
        save()
    }
    private func finish(_ status: String) { record?.status = status; running = false; task = nil; save() }
    private func save() {
        guard let record else { return }
        do {
            try FileManager.default.createDirectory(at: recordURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(record).write(to: recordURL, options: .atomic)
        } catch {
            self.record?.rows.removeAll { $0.metric == "checkpoint_error" }
            self.record?.rows.append(.init(stage: "run", metric: "checkpoint_error", value: error.localizedDescription))
        }
    }
}

struct WSSIGeometryProbeView: View {
    @State private var model = WSSIProbeModel.shared
    private let products = ["Overall_Impact", "Snow_Amount", "Snow_Load", "Ice_Accumulation", "Blowing_Snow"]
    var body: some View {
        Form {
            Section("Configuration") {
                TextField("Forge origin", text: $model.origin).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Pass label (A, B, C)", text: $model.pass)
                TextField("Network conditions (reported)", text: $model.network)
                Picker("Product", selection: $model.product) { ForEach(products, id: \.self) { Text($0).tag($0) } }
                Picker("Day", selection: $model.day) { ForEach(1...3, id: \.self) { Text("Day \($0)").tag($0) } }
                Picker("Operation", selection: $model.mode) { ForEach(WSSIProbeWorker.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            }.disabled(model.running)
            Section("Run") {
                if model.running { Button("Cancel") { model.cancel() } }
                else { Button("Run Test") { model.start() }; Button("Reset") { model.reset() }.disabled(model.record == nil) }
                Text(model.record?.status ?? "No measurements yet").accessibilityIdentifier("wssi-probe-status")
            }
            if let record = model.record {
                Section("Observations") {
                    ForEach(Array(record.rows.enumerated()), id: \.offset) { _, row in
                        LabeledContent("\(row.stage): \(row.metric)", value: row.value)
                    }
                    ShareLink(item: WSSIProbeExport(record: record), preview: SharePreview("WSSI diagnostics")) { Label("Export CSV", systemImage: "square.and.arrow.up") }
                }
            }
        }.navigationTitle("WSSI Geometry Probe")
    }
}
#endif
