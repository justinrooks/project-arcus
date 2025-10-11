//
//  spcService+Environment.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/25/25.
//

import SwiftUI
import CoreLocation

// Crash loudly in DEBUG if you forgot to inject.
private struct MissingSpcService: SpcService {
    func sync() async {
        assertionFailure("⚠️ SpcService not injected into environment")
    }
    
    func syncTextProducts() async {
        assertionFailure("⚠️ SpcService not injected into environment")
    }
    
    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        assertionFailure("⚠️ SpcService not injected into environment"); throw MissingError()
    }
    
    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        assertionFailure("⚠️ SpcService not injected into environment"); throw MissingError()
    }
    
    func cleanup(daysToKeep: Int = 3) async {
        assertionFailure("⚠️ SpcService not injected into environment")
    }
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        assertionFailure(" Not injected "); throw MissingError()
    }
    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        assertionFailure(" NOT INJECTED "); throw MissingError()
    }
    func getStormRiskMapData() async throws -> [StormRiskDTO] {assertionFailure("NOT INJECTED"); throw MissingError()}
    func getMesoMapData() async throws -> [MdDTO] { assertionFailure("NOT INJECTED"); throw MissingError() }
    
    struct MissingError: Error {}
}

extension EnvironmentValues {
    @Entry var spcService: SpcService = MissingSpcService()
}
