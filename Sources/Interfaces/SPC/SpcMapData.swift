//
//  SpcMapData.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

protocol SpcMapData: Sendable {
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO]
    func getStormRiskMapData() async throws -> [StormRiskDTO]
    func getMesoMapData() async throws -> [MdDTO]
    func getFireRisk() async throws -> [FireRiskDTO]
    /// Accepted local snapshots only. nil means never loaded, not confirmed empty.
    func getCategoricalForecast(for day: SPCForecastDay) async throws -> SPCCategoricalForecastSnapshot?
    func getHazardForecast(for day: SPCForecastDay) async throws -> SPCHazardForecastSnapshot?
}

extension SpcMapData {
    func getCategoricalForecast(for day: SPCForecastDay) async throws -> SPCCategoricalForecastSnapshot? { nil }
    func getHazardForecast(for day: SPCForecastDay) async throws -> SPCHazardForecastSnapshot? { nil }
}
