//
//  SpcProviderV1.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import OSLog

actor SpcProvider {
    let logger = Logger.providersSpc
    let signposter:OSSignposter
    let outlookRepo: ConvectiveOutlookRepo
    let mesoRepo: MesoRepo
    let watchRepo: WatchRepo
    let stormRiskRepo: StormRiskRepo
    let severeRiskRepo: SevereRiskRepo
    let fireRiskRepo: FireRiskRepo
    let client: SpcClient
    
    // Convective freshness Stream
    var latestConvective: Date?
    var convectiveContinuations: [UUID: AsyncStream<Date>.Continuation] = [:]
    
    init(outlookRepo: ConvectiveOutlookRepo,
         mesoRepo: MesoRepo,
         watchRepo: WatchRepo,
         stormRiskRepo: StormRiskRepo,
         severeRiskRepo: SevereRiskRepo,
         fireRiskRepo: FireRiskRepo,
         client: SpcClient) {
        signposter = OSSignposter(logger: logger)
        self.outlookRepo = outlookRepo
        self.mesoRepo = mesoRepo
        self.watchRepo = watchRepo
        self.stormRiskRepo = stormRiskRepo
        self.severeRiskRepo = severeRiskRepo
        self.fireRiskRepo = fireRiskRepo
        self.client = client
    }

    func convectiveIssueUpdates() async -> AsyncStream<Date> {
//        AsyncStream<Date>(bufferingPolicy: .bufferingNewest(1)) { continuation in
        AsyncStream<Date> { continuation in
            // Seed with cached value if we have one
            if let latestConvective { continuation.yield(latestConvective) }
            // Store continuation so we can yield future updates
            let id = UUID()
            convectiveContinuations[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.removeConvectiveContinuation(id: id)
                }
            }
        }
    }

    // MARK: Private methods
    private func removeConvectiveContinuation(id: UUID) {
        convectiveContinuations[id] = nil
    }
}
