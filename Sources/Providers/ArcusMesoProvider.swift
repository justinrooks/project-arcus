import ArcusCore
import Foundation

struct ArcusMesoProvider: ArcusMesoQuerying {
    private let client: any ArcusMesoClient

    init(client: any ArcusMesoClient) {
        self.client = client
    }

    func getActiveMesos(h3Cell: Int64? = nil) async throws -> [MesoscaleDiscussionPayload] {
        let data = try await client.fetchActiveMesos(h3Cell: h3Cell)
        do {
            return try DecoderFactory.iso8601.decode([MesoscaleDiscussionPayload].self, from: data)
        } catch {
            throw ArcusError.parsingError
        }
    }

    func getMeso(productID: String) async throws -> MesoscaleDiscussionPayload? {
        do {
            let data = try await client.fetchMeso(productID: productID)
            do {
                let mesos = try DecoderFactory.iso8601.decode([MesoscaleDiscussionPayload].self, from: data)
                guard let meso = mesos.first else { throw ArcusError.parsingError }
                return meso
            } catch let error as ArcusError {
                throw error
            } catch {
                throw ArcusError.parsingError
            }
        } catch ArcusError.networkError(status: 404) {
            return nil
        }
    }
}
