import CryptoKit
import Foundation

enum WSSIObservedPublication {
    static func snapshot(first: WSSIAcquisition, second: WSSIAcquisition, source: URL,
                         startedAt: Date, verifiedAt: Date) throws -> WSSISnapshot {
        guard first.scope == second.scope, first.layers.count == 20, second.layers.count == 20 else {
            throw WSSIAcquisitionError.incompleteInventory
        }
        var layers: [WSSISnapshotLayer] = []
        var digests: [String] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for (product, base) in zip(WSSIProduct.allCases, [1, 6, 11, 16, 24]) {
            for (offset, period) in WSSIPeriod.allCases.enumerated() {
                let id = base + offset
                guard first.layers.filter({ $0.id == id }).count == 1,
                      second.layers.filter({ $0.id == id }).count == 1,
                      let a = first.layers.first(where: { $0.id == id }),
                      let b = second.layers.first(where: { $0.id == id }) else {
                    throw WSSIAcquisitionError.incompleteInventory
                }
                func keyed(_ layer: WSSIAcquisition.Layer) throws -> [Int: WSSIFeature] {
                    guard layer.objectIDs.count == layer.collection.features.count,
                          Set(layer.objectIDs).count == layer.objectIDs.count else {
                        throw WSSIAcquisitionError.incompleteInventory
                    }
                    return Dictionary(uniqueKeysWithValues: zip(layer.objectIDs, layer.collection.features))
                }
                let values = try keyed(b)
                guard try keyed(a) == values else { throw WSSIAcquisitionError.changedPublication }
                let features = values.keys.sorted().compactMap { values[$0] }
                let metadata = features.first
                let layer = WSSISnapshotLayer(product: product, period: period,
                    state: metadata == nil ? .observedEmpty : .identifiedData,
                    issuedAt: metadata?.issuedAt, validFrom: metadata?.validFrom, validTo: metadata?.validTo,
                    features: features)
                // Keep per-layer source dates; mixed metadata inside one layer fails validation.
                _ = try layer.assessmentLayer(in: second.scope)
                try Task.checkCancellation()
                layers.append(layer)
                digests.append("\(id):\(SHA256.hash(data: try encoder.encode(layer)).description)")
            }
        }
        let requests = (first.layers + second.layers).flatMap(\.requests)
        let provenance = "two unconditional scans; requests=\(requests.count); decodedBytes=" +
            "\(requests.reduce(0) { $0 + $1.decodedByteCount }); layerSHA256=\(digests.joined(separator: ","))"
        let snapshot = WSSISnapshot(scope: second.scope, source: source, acquisitionStartedAt: startedAt,
                                    verifiedAt: verifiedAt, provenance: provenance, layers: layers)
        try snapshot.validate()
        return snapshot
    }
}
