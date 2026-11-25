import Foundation
import SwiftData

@Model
final class WSSIAcceptedSlot {
    @Attribute(.unique) private(set) var key: String
    private var product: String
    private var day: Int
    private var revision: UUID
    private var issuedAt: Date
    private var validFrom: Date
    private var validTo: Date
    private var gisFileDate: Date?
    private var gisIngestDate: Date?
    private var retrievedAt: Date
    private var geometryPath: String
    private var coverage: String
    private var geometry: Data
    private var eTag: String?

    init(key: String, entry: WSSIManifestEntry, accepted: WSSIAcceptedRevision, geometry: Data, eTag: String?) {
        self.key = key
        product = entry.product.rawValue
        day = entry.day
        revision = accepted.revision
        issuedAt = accepted.issuedAt
        validFrom = accepted.validFrom
        validTo = accepted.validTo
        gisFileDate = accepted.gisFileDate
        gisIngestDate = accepted.gisIngestDate
        retrievedAt = accepted.retrievedAt
        geometryPath = accepted.geometryPath
        coverage = entry.coverage.rawValue
        self.geometry = geometry
        self.eTag = eTag
    }

    var revisionID: UUID? {
        guard WSSIProduct(rawValue: product) != nil, WSSICoverage(rawValue: coverage) != nil else { return nil }
        return revision
    }

    fileprivate var revisionDetails: WSSIAcceptedRevision {
        .init(revision: revision, issuedAt: issuedAt, validFrom: validFrom, validTo: validTo,
              gisFileDate: gisFileDate, gisIngestDate: gisIngestDate, retrievedAt: retrievedAt,
              geometryPath: geometryPath)
    }

    var snapshot: WSSIAcceptedStore.Slot? {
        guard let product = WSSIProduct(rawValue: product), let coverage = WSSICoverage(rawValue: coverage) else {
            return nil
        }
        return .init(product: product, day: day, revision: revisionDetails,
                     coverage: coverage, geometry: geometry, eTag: eTag)
    }
}

@Model
final class WSSIStoredManifest {
    @Attribute(.unique) private(set) var key: String = "manifest"
    private(set) var generation: UUID
    private(set) var body: Data
    private(set) var eTag: String?

    init(body: Data, eTag: String?) {
        generation = UUID()
        self.body = body
        self.eTag = eTag
    }
}

/// One owner per container. Callers capture the manifest generation before starting a request.
@ModelActor
actor WSSIAcceptedStore {
    private var save: @Sendable (ModelContext) throws -> Void = { try $0.save() }

    private var onCommit: (@Sendable () async -> Void)?

    init(
        modelContainer: ModelContainer,
        save: @escaping @Sendable (ModelContext) throws -> Void,
        onCommit: (@Sendable () async -> Void)? = nil
    ) {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.modelContainer = modelContainer
        self.save = save
        self.onCommit = onCommit
    }

    struct Manifest: Sendable {
        let generation: UUID
        let document: WSSIManifest
        let eTag: String?
    }

    struct Slot: Sendable {
        let product: WSSIProduct
        let day: Int
        let revision: WSSIAcceptedRevision
        let coverage: WSSICoverage
        let geometry: Data
        let eTag: String?

        func validity(at time: Date) -> WSSIValidity {
            if time < revision.validFrom { return .notYetValid }
            return time < revision.validTo ? .valid : .expired
        }
    }

    enum Rejection: Error, Equatable {
        case supersededManifest
        case unadvertisedRevision
        case staleRevision
        case conflictingRevision
    }

    func manifest() throws -> Manifest? {
        guard let row = try manifestRow(),
              let document = try? Self.usableManifest(from: row.body) else { return nil }
        return Manifest(generation: row.generation, document: document, eTag: row.eTag)
    }

    func slot(product: WSSIProduct, day: Int) throws -> Slot? {
        try slotRow(key: Self.key(product, day))?.snapshot
    }

    func acceptedRevision(product: WSSIProduct, day: Int, manifestGeneration: UUID) throws -> UUID? {
        try requireManifestGeneration(manifestGeneration)
        return try slotRow(key: Self.key(product, day))?.revisionID
    }

    func requireManifestGeneration(_ generation: UUID) throws {
        guard try manifestRow()?.generation == generation else { throw Rejection.supersededManifest }
    }

    /// A 304 leaves this representation in place. Its entries still need comparison with local slots.
    @discardableResult
    func saveManifest(_ body: Data, eTag: String?, replacing generation: UUID?) async throws -> Manifest {
        let document = try Self.usableManifest(from: body)
        let previous = try manifestRow()
        let usableGeneration = previous.flatMap { row in
            (try? Self.usableManifest(from: row.body)).map { _ in row.generation }
        }
        guard usableGeneration == generation else { throw Rejection.supersededManifest }
        try Self.checkAcceptanceCancellation()
        let row = WSSIStoredManifest(body: body, eTag: Self.validatedETag(eTag))
        let saved = Manifest(generation: row.generation, document: document, eTag: row.eTag)
        try await transaction {
            if let previous { modelContext.delete(previous) }
            modelContext.insert(row)
        }
        return saved
    }

    /// The manifest remains durable even when some geometry requests fail or never start.
    /// Revalidating the same immutable revision leaves the accepted row intact.
    func acceptGeometry(
        _ geometry: Data, eTag: String?, product: WSSIProduct, day: Int, manifestGeneration: UUID
    ) async throws {
        guard let manifest = try manifest(), manifest.generation == manifestGeneration else {
            throw Rejection.supersededManifest
        }
        guard let entry = manifest.document.datasets.first(where: { $0.product == product && $0.day == day }),
              let candidate = entry.accepted else { throw Rejection.unadvertisedRevision }
        _ = try WSSISourceDecoder.geometry(from: geometry, for: entry)
        let key = Self.key(product, day)
        let row = try slotRow(key: key)
        if let row, row.revisionID != nil {
            let current = row.revisionDetails
            if candidate.revision == current.revision {
                guard let snapshot = row.snapshot, candidate == current, entry.coverage == snapshot.coverage,
                      geometry == snapshot.geometry else { throw Rejection.conflictingRevision }
                return
            }
            // Mirror Forge's issuance ordering and its correction rule for equal issuance.
            let newerCorrection = candidate.issuedAt == current.issuedAt &&
                candidate.gisFileDate.map { fileDate in
                    current.gisFileDate.map { fileDate > $0 } ?? false
                } == true
            guard candidate.issuedAt > current.issuedAt || newerCorrection else {
                throw Rejection.staleRevision
            }
        }
        try Self.checkAcceptanceCancellation()
        try await transaction {
            if let row { modelContext.delete(row) }
            modelContext.insert(WSSIAcceptedSlot(
                key: key, entry: entry, accepted: candidate, geometry: geometry, eTag: Self.validatedETag(eTag)
            ))
        }
    }

    private func manifestRow() throws -> WSSIStoredManifest? {
        var descriptor = FetchDescriptor<WSSIStoredManifest>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func checkAcceptanceCancellation() throws {
        try Task.checkCancellation()
        if let context = BackgroundRefreshExecutionContext.current,
           ContinuousClock.now >= context.budget.workDeadline {
            throw CancellationError()
        }
    }

    private func slotRow(key: String) throws -> WSSIAcceptedSlot? {
        var descriptor = FetchDescriptor<WSSIAcceptedSlot>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func key(_ product: WSSIProduct, _ day: Int) -> String {
        "\(product.rawValue):\(day)"
    }

    private static func usableManifest(from body: Data) throws -> WSSIManifest {
        let manifest = try WSSISourceDecoder.manifest(from: body)
        guard manifest.datasets.allSatisfy({ $0.accepted == nil || $0.canonicalGeometryPath != nil }) else {
            throw WSSISourceDecoder.Error.invalidManifest
        }
        return manifest
    }

    private static func validatedETag(_ eTag: String?) -> String? {
        eTag.flatMap { HTTPETag.opaqueValue($0) == nil ? nil : $0 }
    }

    private func transaction(_ change: () -> Void) async throws {
        modelContext.autosaveEnabled = false
        do {
            change()
            try save(modelContext)
        } catch {
            modelContext.rollback()
            throw error
        }
        // Manifest metadata and geometry are both inputs to the accepted assessment.
        await onCommit?()
    }
}
