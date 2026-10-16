import ArcusCore
import Foundation

struct ArcusMesoProvider: ArcusMesoQuerying {
    private let client: any ArcusMesoClient

    init(client: any ArcusMesoClient) {
        self.client = client
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
