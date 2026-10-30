import ArcusCore
import Foundation

protocol RemoteMesoResolving: Sendable {
    func acceptedNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload?
    func resolveNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload?
}

actor ArcusMesoProvider: ArcusMesoQuerying, RemoteMesoResolving {
    private let client: any ArcusMesoClient
    private let repo: MesoRepo?
    private let homeProjections: (any AcceptedHomeMesoReading)?
    private let now: @Sendable () -> Date
    private struct TargetKey: Hashable {
        let productID: String
        // A caller with a different lifetime must not inherit another receipt's HTTP deadline.
        let deadline: ContinuousClock.Instant?
    }
    private struct TargetRun {
        let task: Task<MesoscaleDiscussionPayload?, Error>
        var owners: Set<UUID>
    }
    private var inFlightTargets: [TargetKey: TargetRun] = [:]
    private(set) var coalescedTargetCount = 0

    init(
        client: any ArcusMesoClient,
        repo: MesoRepo? = nil,
        homeProjections: (any AcceptedHomeMesoReading)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.repo = repo
        self.homeProjections = homeProjections
        self.now = now
    }

    func getActiveMesos(
        h3Cell: Int64? = nil
    ) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]> {
        let response = try await client.fetchActiveMesos(h3Cell: h3Cell)
        let mesos = try Self.decodeMesos(from: response)
        return ArcusMesoQueryResponse(value: mesos, source: response.source)
    }

    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>? {
        do {
            let response = try await client.fetchMeso(productID: productID)
            guard let meso = try Self.decodeMesos(from: response).first else { throw ArcusError.parsingError }
            return ArcusMesoQueryResponse(value: meso, source: response.source)
        } catch ArcusError.networkError(status: 404) {
            return nil
        }
    }

    func acceptedNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload? {
        if let meso = try await homeProjections?.notificationMeso(productID: productID, at: now()) { return meso }
        guard let repo else { return nil }
        return try await repo.notificationMeso(productID: productID, at: now())
    }

    func resolveNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload? {
        if let cached = try await acceptedNotificationMeso(productID: productID) { return cached }
        try Task.checkCancellation()
        let key = TargetKey(
            productID: productID, deadline: BackgroundRefreshExecutionContext.current?.budget.workDeadline
        )
        let owner = UUID()
        let task: Task<MesoscaleDiscussionPayload?, Error>
        if var run = inFlightTargets[key] {
            coalescedTargetCount += 1
            run.owners.insert(owner)
            inFlightTargets[key] = run
            task = run.task
        } else {
            guard let repo else { throw ArcusError.missingData }
            task = Task {
                guard let response = try await self.getMeso(productID: productID),
                      response.source == .live || response.source == .cacheRevalidated304,
                      response.value.productID == productID else { return nil }
                try Task.checkCancellation()
                return try await repo.acceptNotificationMeso(response.value, at: self.now())
            }
            inFlightTargets[key] = TargetRun(task: task, owners: [owner])
        }
        defer { removeOwner(owner, from: key) }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result.flatMap { $0.validStart <= now() && now() < $0.validEnd ? $0 : nil }
        } onCancel: {
            Task { await self.removeOwner(owner, from: key) }
        }
    }

    private func removeOwner(_ owner: UUID, from key: TargetKey) {
        guard var run = inFlightTargets[key], run.owners.remove(owner) != nil else { return }
        if run.owners.isEmpty {
            // Preserve existing unbudgeted open-resolution semantics; receipt-only work is cancellable.
            if key.deadline != nil { run.task.cancel() }
            inFlightTargets[key] = nil
        } else {
            inFlightTargets[key] = run
        }
    }

    private static func decodeMesos(from response: HTTPResponse) throws -> [MesoscaleDiscussionPayload] {
        guard let data = response.data else { throw ArcusError.missingData }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        do {
            return try decoder.decode([MesoscaleDiscussionPayload].self, from: data)
        } catch {
            throw ArcusError.parsingError
        }
    }
}
