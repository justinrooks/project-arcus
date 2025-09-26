//
//  SummaryBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI
import MapKit

struct SummaryBadgeView: View {
    @Environment(\.spcService) private var svc: any SpcService
    @Environment(LocationManager.self) private var locationProvider: LocationManager
    
    @State private var stormRisk: StormRiskLevel = .allClear
    @State private var severeRisk: SevereWeatherThreat = .allClear
    
    var body: some View {
        // Badges
        HStack {
            StormRiskBadgeView(level: stormRisk)
            Spacer()
            SevereWeatherBadgeView(threat: severeRisk)
        }
        .padding(.vertical, 5)
//            .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            Task {
                stormRisk = try await svc.getStormRisk(for: locationProvider.resolvedUserLocation)
                severeRisk = try await svc.getSevereRisk(for: locationProvider.resolvedUserLocation)
            }
        }
    }
}

#Preview("Slight + 10% Tornado") {
    // Mock service that returns deterministic values for previews
    struct MockSpcService: SpcService {
        let storm: StormRiskLevel
        let severe: SevereWeatherThreat

        func sync() async {}
        func syncTextProducts() async {}
        func cleanup(daysToKeep: Int) async {}

        func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
            storm
        }

        func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
            severe
        }
        func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }
    }

    let mockLocation = LocationManager() // uses fallback coordinate if no real location
    let mockService = MockSpcService(
        storm: .slight,
        severe: .tornado(probability: 0.10)
    )

    return SummaryBadgeView()
        .environment(mockLocation)
        .environment(\.spcService, mockService)
}

#Preview("All Clear") {
    struct MockSpcService: SpcService {
        func sync() async {}
        func syncTextProducts() async {}
        func cleanup(daysToKeep: Int) async {}

        func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel { .allClear }
        func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat { .allClear }
        func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }
    }

    return SummaryBadgeView()
        .environment(LocationManager())
        .environment(\.spcService, MockSpcService())
}

#Preview("Enhanced + 30% Hail") {
    struct MockSpcService: SpcService {
        func sync() async {}
        func syncTextProducts() async {}
        func cleanup(daysToKeep: Int) async {}

        func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel { .enhanced }
        func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat { .hail(probability: 0.30) }
        
        func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }
    }

    return SummaryBadgeView()
        .environment(LocationManager())
        .environment(\.spcService, MockSpcService())
}
