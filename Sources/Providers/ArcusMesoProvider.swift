import ArcusCore
import Foundation

protocol RemoteMesoResolving: Sendable {
    func acceptedNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload?
    func resolveNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload?
}

actor ArcusMesoProvider: ArcusMesoQuerying, RemoteMesoResolving {
    private let client: any ArcusMesoClient
    private let repo: MesoRepo?
    private let now: @Sendable () -> Date
    private var inFlightTargets: [String: Task<MesoscaleDiscussionPayload?, Error>] = [:]
    private(set) var coalescedTargetCount = 0

    init(client: any ArcusMesoClient, repo: MesoRepo? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.repo = repo
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
        guard let repo else { return nil }
        return try await repo.notificationMeso(productID: productID, at: now())
    }

    func resolveNotificationMeso(productID: String) async throws -> MesoscaleDiscussionPayload? {
        if let cached = try await acceptedNotificationMeso(productID: productID) { return cached }
        try Task.checkCancellation()
        // Coalesce through repository acceptance, not just HTTP, so every waiter reads saved state.
        if let task = inFlightTargets[productID] {
            coalescedTargetCount += 1
            let result = try await task.value
            try Task.checkCancellation()
            return result.flatMap { $0.validStart <= now() && now() < $0.validEnd ? $0 : nil }
        }
        guard let repo else { throw ArcusError.missingData }
        let task = Task {
            guard let response = try await self.getMeso(productID: productID),
                  response.source == .live || response.source == .cacheRevalidated304,
                  response.value.productID == productID else { return nil as MesoscaleDiscussionPayload? }
            return try await repo.acceptNotificationMeso(response.value, at: self.now())
        }
        inFlightTargets[productID] = task
        defer { inFlightTargets[productID] = nil }
        let result = try await task.value
        try Task.checkCancellation()
        return result.flatMap { $0.validStart <= now() && now() < $0.validEnd ? $0 : nil }
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
