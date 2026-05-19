//
//  ArcusAlertQuerying.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

protocol ArcusAlertQuerying: Sendable {
    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO]
    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry]
    func getAlert(id: String) async throws -> AlertDTO?
}

extension ArcusAlertQuerying {
    func getActiveWarningGeometries() async throws -> [ActiveWarningGeometry] {
        try await getActiveWarningGeometries(on: .now)
    }
}
