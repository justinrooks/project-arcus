import ArcusCore
import Foundation

protocol ArcusMesoQuerying: Sendable {
    func getActiveMesos(h3Cell: Int64?) async throws -> [MesoscaleDiscussionPayload]
    func getMeso(productID: String) async throws -> MesoscaleDiscussionPayload?
}
