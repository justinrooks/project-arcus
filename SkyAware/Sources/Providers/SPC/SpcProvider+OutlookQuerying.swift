//
//  SpcProvider+OutlookQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/12/25.
//

import Foundation

extension SpcProvider: SpcOutlookQuerying {
    
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        try await outlookRepo.current()
    }
    
    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        try await outlookRepo.fetchConvectiveOutlooks()
    }
}
