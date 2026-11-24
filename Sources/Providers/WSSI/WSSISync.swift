import Foundation

/// One sync owner for the accepted WSSI store. Callers join the same sequential workload.
actor WSSISync {
    enum Outcome: Equatable, Sendable {
        case disabled, cancelled, superseded
        case reconciled(ManifestUpdate, [SlotResult])
        case manifestFailed(Failure, retainedManifest: Bool)
    }

    enum ManifestUpdate: Equatable, Sendable { case updated, revalidated }

    struct SlotResult: Equatable, Sendable {
        enum Outcome: Equatable, Sendable {
            case current(UUID), accepted(UUID)
            case unavailable(retainedRevision: UUID?)
            case failed(Failure, retainedRevision: UUID?)
        }

        let product: WSSIProduct
        let day: Int
        let outcome: Outcome
    }

    enum Failure: Equatable, Sendable {
        case httpStatus(Int, retryAfterSeconds: Int?)
        case transport, invalidRepresentation, storage, staleRevision, conflictingRevision

        init(_ error: any Error, otherwise: Self) {
            switch error {
            case ForgeWSSIClient.Error.httpStatus(let status, let retryAfter):
                self = .httpStatus(status, retryAfterSeconds: retryAfter)
            case is ForgeWSSIClient.Error, is DecodingError, is WSSISourceDecoder.Error,
                 WSSIAcceptedStore.Rejection.unadvertisedRevision:
                self = .invalidRepresentation
            case WSSIAcceptedStore.Rejection.staleRevision: self = .staleRevision
            case WSSIAcceptedStore.Rejection.conflictingRevision: self = .conflictingRevision
            default: self = otherwise
            }
        }
    }

    private struct Waiter {
        let joinsActiveWorkload: Bool
        let continuation: CheckedContinuation<Outcome?, Never>
    }

    private let client: ForgeWSSIClient
    private let store: WSSIAcceptedStore
    private var workload: Task<Void, Never>?
    private var executionContext: BackgroundRefreshExecutionContext?
    private var waiters: [UUID: Waiter] = [:]

    #if DEBUG
    var waiterCount: Int { waiters.count }

    func waitForWorkloadToFinish() async { await workload?.value }
    #endif

    init(client: ForgeWSSIClient, store: WSSIAcceptedStore) {
        self.client = client
        self.store = store
    }

    func refresh(enabled: Bool) async -> Outcome {
        guard enabled else { return .disabled }
        while !Task.isCancelled {
            if let outcome = await joinOrWaitForWorkload() {
                return Task.isCancelled ? .cancelled : outcome
            }
        }
        return .cancelled
    }

    // Nil releases a queued caller to start or join the next workload with its original task locals.
    private func joinOrWaitForWorkload() async -> Outcome? {
        let id = UUID()
        let context = HTTPExecutionMode.current == .background ? BackgroundRefreshExecutionContext.current : nil
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // A draining request or a different OS deadline must finish before this caller starts.
                let joins = workload == nil || (workload?.isCancelled == false
                    && executionContext?.deadlineState === context?.deadlineState
                    && executionContext?.budget.workDeadline == context?.budget.workDeadline)
                waiters[id] = Waiter(joinsActiveWorkload: joins, continuation: continuation)
                if workload == nil { startWorkload(context: context) }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func startWorkload(context: BackgroundRefreshExecutionContext?) {
        executionContext = context
        workload = Task {
            let outcome = await reconcile()
            let completed = waiters
            waiters.removeAll()
            workload = nil
            executionContext = nil
            for waiter in completed.values {
                waiter.continuation.resume(returning: waiter.joinsActiveWorkload ? outcome : nil)
            }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        if waiter.joinsActiveWorkload, !waiters.values.contains(where: \.joinsActiveWorkload) {
            workload?.cancel()
        }
        waiter.continuation.resume(returning: .cancelled)
    }

    private func reconcile() async -> Outcome {
        var previous: WSSIAcceptedStore.Manifest?
        var failureSource = Failure.storage
        do {
            try Task.checkCancellation()
            previous = try await store.manifest()
            failureSource = .transport
            let response = try await fetchManifest(ifNoneMatch: previous?.eTag)
            failureSource = .storage
            let manifest: WSSIAcceptedStore.Manifest
            let update: ManifestUpdate
            switch response.outcome {
            case .body(let body):
                manifest = try await store.saveManifest(body, eTag: response.eTag, replacing: previous?.generation)
                update = .updated
            case .notModified:
                guard let previous else { throw ForgeWSSIClient.Error.invalidNotModified }
                manifest = previous
                update = .revalidated
            }

            var slots: [SlotResult] = []
            for entry in manifest.document.datasets {
                let outcome = try await reconcile(entry, generation: manifest.generation)
                slots.append(.init(product: entry.product, day: entry.day, outcome: outcome))
            }
            try await store.requireManifestGeneration(manifest.generation)
            try Task.checkCancellation()
            return .reconciled(update, slots)
        } catch {
            if Self.isCancellation(error) { return .cancelled }
            if Self.isSuperseded(error) { return .superseded }
            return .manifestFailed(Failure(error, otherwise: failureSource), retainedManifest: previous != nil)
        }
    }

    private func fetchManifest(ifNoneMatch eTag: String?) async throws -> ForgeWSSIClient.Response {
        do {
            return try await client.fetchManifest(ifNoneMatch: eTag)
        } catch ForgeWSSIClient.Error.invalidNotModified where eTag != nil {
            // A mismatched validator cannot revalidate the durable representation.
            return try await client.fetchManifest()
        }
    }

    private func reconcile(_ entry: WSSIManifestEntry, generation: UUID) async throws -> SlotResult.Outcome {
        try Task.checkCancellation()
        var current: UUID?
        var failureSource = Failure.storage
        do {
            current = try await store.acceptedRevision(product: entry.product, day: entry.day,
                                                       manifestGeneration: generation)
            guard let advertised = entry.accepted?.revision else { return .unavailable(retainedRevision: current) }
            if current == advertised { return .current(advertised) }

            failureSource = .transport
            // Missing immutable revisions require a complete body. The HTTP client owns retries and backoff.
            let response = try await client.fetchGeometry(for: entry)
            guard case .body(let geometry) = response.outcome else { throw ForgeWSSIClient.Error.invalidNotModified }
            failureSource = .storage
            try await store.acceptGeometry(geometry, eTag: response.eTag, product: entry.product,
                                           day: entry.day, manifestGeneration: generation)
            return .accepted(advertised)
        } catch {
            if Self.isCancellation(error) || Self.isSuperseded(error) { throw error }
            return .failed(Failure(error, otherwise: failureSource), retainedRevision: current)
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private static func isSuperseded(_ error: any Error) -> Bool {
        (error as? WSSIAcceptedStore.Rejection) == .supersededManifest
    }
}
