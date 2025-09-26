//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import CoreLocation

struct SummaryView: View {
    
    var body: some View {
        VStack {
            // Header
            SummaryHeaderView()
            
            // Badges
            SummaryBadgeView()
            
            //Mesos
            ActiveMesoSummaryView()
    
            GroupBox{
                Divider()
                HStack {
                    Text("No active watches in your area")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } label: {
                Label("Nearby Watches", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.teal)
            }
            
            GroupBox {
                //                Text("Scattered severe storms with damaging winds are possible into this evening across parts of the Lower and Middle Ohio Valley. The greatest threat is in northeast Lower Michigan, where isolated hail or a tornado is possible. Further south, clusters of storms may bring damaging wind gusts through Indiana, Kentucky, and Ohio. Lesser threats exist in Oklahoma, New Mexico, and Upper Michigan.")
                //                Text("Severe storms are expected this afternoon and evening across the Lower/Middle Ohio Valley, especially Indiana, Kentucky, and Ohio, with damaging wind the main threat. In northeast Lower Michigan, supercells could form with a risk of hail, damaging winds, and possibly a tornado. Scattered storms may also develop in Oklahoma, North Texas, New Mexico, and Upper Michigan, but the overall severe threat in those areas is more isolated.")
                Text("A Slight Risk is in place from northeast Lower Michigan into the Lower and Middle Ohio Valley. In Michigan, filtered heating, strong low-level flow, and modest instability (MLCAPE 1000–1500 J/kg) may allow supercells with wind, hail, and isolated tornadoes. Farther south, scattered storms from southern Illinois through Indiana and into Ohio/Kentucky may form multicell clusters with damaging winds as the main hazard. Additional isolated severe storms are possible in Oklahoma and North Texas, aided by MCVs, and over the high terrain of New Mexico and Colorado, where hail is the main concern. Activity diminishes tonight.")
            } label: {
                Label("Outlook Summary", systemImage: "sun.max.fill")
                    .foregroundStyle(.teal)
            }
        }
        .padding(.horizontal)
    }
}

#Preview("Summary – Slight + 10% Tornado") {
    // Local mock for SpcService used by SummaryBadgeView
    struct MockSpcService: SpcService {
        let storm: StormRiskLevel
        let severe: SevereWeatherThreat

        func sync() async {}
        func syncTextProducts() async {}
        func cleanup(daysToKeep: Int) async {}

        func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel { storm }
        func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat { severe }
        func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] { [] }
    }

    // Seed some sample Mesos so ActiveMesoSummaryView has content
    let mdPreview = Preview(MD.self)
    mdPreview.addExamples(MD.sampleDiscussions)

    let location = LocationManager()
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))

    return NavigationStack {
        SummaryView()
            .modelContainer(mdPreview.container)
            .environment(location)
            .environment(\.spcService, spcMock)
            .padding()
    }
}
