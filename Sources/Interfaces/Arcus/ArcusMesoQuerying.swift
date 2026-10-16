import ArcusCore
import Foundation

protocol ArcusMesoQuerying: Sendable {
    func getActiveMesos(h3Cell: Int64?) async throws -> ArcusMesoQueryResponse<[MesoscaleDiscussionPayload]>
    func getMeso(productID: String) async throws -> ArcusMesoQueryResponse<MesoscaleDiscussionPayload>?
}

struct ArcusMesoQueryResponse<Value: Sendable>: Sendable {
    let value: Value
    let source: HTTPResponse.Source
}
