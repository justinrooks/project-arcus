//
//  SpcOutlookQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/12/25.
//

import Foundation

protocol SpcOutlookQuerying: Sendable {
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO?
    
    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO]
}
