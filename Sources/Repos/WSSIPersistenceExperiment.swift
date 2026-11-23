#if DEBUG
import Darwin
import Foundation
import SwiftData

@Model
private final class WSSIExperimentPayload {
    var product: String
    var day: Int
    var revision: String
    var geometry: Data

    init(metadata: WSSIGeometryExperiment.Metadata, geometry: Data) {
        self.product = metadata.product
        self.day = metadata.day
        self.revision = metadata.revision.uuidString
        self.geometry = geometry
    }
}

/// Owns only disposable experiment stores. No contexts or models cross the actor boundary.
actor WSSIPersistenceExperiment {
    struct Sample: Sendable {
        let stage: String
        let elapsed: Duration
        let databaseAllocatedBytes: Int
        let walAllocatedBytes: Int
        let footprintBytes: UInt64?
    }

    struct Report: Sendable {
        let fixture: String
        let metadata: WSSIGeometryExperiment.Metadata
        let retainedPayloadBytes: Int
        let replacementRevisions: [UUID]
        let samples: [Sample]
        let footprintBeforeLoad: UInt64?
        let footprintAfterRelease: UInt64?
    }

    enum Failure: Error, Equatable {
        case injectedBeforeReplacementSave
        case unexpectedReadback
        case ambiguousRevisionEncoding
    }

    private let temporaryDirectory: URL

    init(temporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        self.temporaryDirectory = temporaryDirectory
    }

    func run(fixture: URL, injectFailure: Bool = false) throws -> Report {
        try Task.checkCancellation()
        let files = FileManager.default
        let directory = temporaryDirectory.appending(path: "wssi-persistence-\(UUID())", directoryHint: .isDirectory)
        try files.createDirectory(at: directory, withIntermediateDirectories: false)
        let before = WSSIGeometryExperiment.footprint()
        let result: (metadata: WSSIGeometryExperiment.Metadata, bytes: Int, revisions: [UUID], samples: [Sample])
        do {
            result = try autoreleasepool {
                try measure(fixture: fixture, store: directory.appending(path: "experiment.sqlite"),
                            injectFailure: injectFailure)
            }
        } catch {
            try files.removeItem(at: directory)
            throw error
        }
        let after = WSSIGeometryExperiment.footprint()
        try files.removeItem(at: directory)
        try Task.checkCancellation()
        return Report(fixture: fixture.lastPathComponent, metadata: result.metadata, retainedPayloadBytes: result.bytes,
                      replacementRevisions: result.revisions, samples: result.samples, footprintBeforeLoad: before,
                      footprintAfterRelease: after)
    }

    private func measure(fixture: URL, store: URL, injectFailure: Bool) throws ->
        (metadata: WSSIGeometryExperiment.Metadata, bytes: Int, revisions: [UUID], samples: [Sample]) {
        var data = try Data(contentsOf: fixture)
        let source = try WSSIGeometryExperiment.measure(data, fixtureIdentity: fixture.lastPathComponent,
                                                        points: []).metadata
        let revisionRange = try revisionRange(in: data, revision: source.revision)
        var metadata = source
        var revisions: [UUID] = []
        let clock = ContinuousClock()
        var samples: [Sample] = []
        try autoreleasepool {
            let context = try open(store)
            samples.append(try sample("empty store", elapsed: .zero, store: store))
            let start = clock.now
            context.insert(WSSIExperimentPayload(metadata: metadata, geometry: data))
            try Task.checkCancellation()
            try context.save()
            samples.append(try sample("insert + save", elapsed: start.duration(to: clock.now), store: store))
            let readStart = clock.now
            try verify(try fetch(context), metadata: metadata, data: data)
            samples.append(try sample("initial fetch", elapsed: readStart.duration(to: clock.now), store: store))
        }

        // Each pool drops all references to the previous container before opening the same URL.
        // Change only the encoded UUID, keeping full geometry and payload size fixed across synthetic revisions.
        for index in 1...4 {
            try Task.checkCancellation()
            try autoreleasepool {
                let openStart = clock.now
                let context = try open(store)
                samples.append(try sample("reopen \(index)", elapsed: openStart.duration(to: clock.now), store: store))
                let readStart = clock.now
                let row = try fetch(context)
                try verify(row, metadata: metadata, data: data)
                samples.append(try sample("fetch \(index)", elapsed: readStart.duration(to: clock.now), store: store))
                guard index <= 3 else { return }
                var identifier = source.revision.uuid
                identifier.15 ^= UInt8(index)
                let revision = UUID(uuid: identifier)
                let replacement = WSSIGeometryExperiment.Metadata(product: source.product, day: source.day,
                                                                  revision: revision)
                var updatedData = data
                updatedData.replaceSubrange(revisionRange, with: revision.uuidString.lowercased().utf8)
                let writeStart = clock.now
                context.delete(row)
                context.insert(WSSIExperimentPayload(metadata: replacement, geometry: updatedData))
                do {
                    if injectFailure { throw Failure.injectedBeforeReplacementSave }
                    try Task.checkCancellation()
                    try context.save()
                } catch {
                    context.rollback()
                    try verify(try fetch(context), metadata: metadata, data: data)
                    throw error
                }
                samples.append(try sample("replace \(index) + save", elapsed: writeStart.duration(to: clock.now),
                                          store: store))
                data = updatedData
                metadata = replacement
                revisions.append(revision)
            }
        }
        return (source, data.count, revisions, samples)
    }

    private func revisionRange(in data: Data, revision: UUID) throws -> Range<Data.Index> {
        let match = Data(revision.uuidString.lowercased().utf8)
        guard let range = data.range(of: match),
              data.range(of: match, in: range.upperBound..<data.endIndex) == nil else {
            throw Failure.ambiguousRevisionEncoding
        }
        return range
    }

    private func open(_ store: URL) throws -> ModelContext {
        let schema = Schema([WSSIExperimentPayload.self])
        let configuration = ModelConfiguration(schema: schema, url: store, cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
        context.autosaveEnabled = false
        return context
    }

    private func fetch(_ context: ModelContext) throws -> WSSIExperimentPayload {
        var descriptor = FetchDescriptor<WSSIExperimentPayload>()
        descriptor.fetchLimit = 2
        let rows = try context.fetch(descriptor)
        guard rows.count == 1, let row = rows.first else { throw Failure.unexpectedReadback }
        return row
    }

    private func verify(_ row: WSSIExperimentPayload, metadata: WSSIGeometryExperiment.Metadata,
                        data: Data) throws {
        guard row.product == metadata.product, row.day == metadata.day,
              row.revision == metadata.revision.uuidString,
              row.geometry == data else {
            throw Failure.unexpectedReadback
        }
    }

    private func sample(_ stage: String, elapsed: Duration, store: URL) throws -> Sample {
        let wal = store.deletingLastPathComponent().appending(path: store.lastPathComponent + "-wal")
        return Sample(stage: stage, elapsed: elapsed, databaseAllocatedBytes: try allocatedSize(store),
                      walAllocatedBytes: try allocatedSize(wal, mayBeMissing: true),
                      footprintBytes: WSSIGeometryExperiment.footprint())
    }

    private func allocatedSize(_ url: URL, mayBeMissing: Bool = false) throws -> Int {
        // Read the current allocation on every sample. URL resource values can be cached.
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            let code = errno
            if mayBeMissing && code == ENOENT { return 0 }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        return Int(info.st_blocks) * 512
    }
}
#endif
