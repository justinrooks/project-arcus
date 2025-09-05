//
//  SummaryBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI
import MapKit

struct SummaryBadgeView: View {
//    @Environment(LocationManager.self) private var locationProvider: LocationManager
//    @Environment(SpcProvider.self) private var spcProvider: SpcProvider
    @Environment(SummaryProvider.self) private var summary: SummaryProvider
    
    var body: some View {
        // Badges
        HStack {
            NavigationLink(destination: ConvectiveOutlookView()) {
                StormRiskBadgeView(level: summary.getStormRisk())
            }
            Spacer()
            NavigationLink(destination: SevereThreatView()) {
                SevereWeatherBadgeView(threat: summary.getSevereRisk())
            }
        }
        .padding(.vertical, 5)
//            .fixedSize(horizontal: true, vertical: true)
    }
}

// Abstract this out into some other sort of provider
// new provider will need a SpcProvider, locationmanager
// we need this in the badge view, and want to use it in
// the background task in the am to report conditions

//extension SummaryBadgeView {
//    var stormRisk: StormRiskLevel {
//        let titleToRisk: [String: StormRiskLevel] = [
//            "GENERAL THUNDERSTORMS RISK": .thunderstorm,
//            "MARGINAL RISK": .marginal,
//            "SLIGHT RISK": .slight,
//            "ENHANCED RISK": .enhanced,
//            "MODERATE RISK": .moderate,
//            "HIGH RISK": .high
//        ]
//        
//        let matchingPolygons: [(StormRiskLevel, MKPolygon)] = spcProvider.categorical.flatMap{$0.polygons}.compactMap { polygon in
//            guard let title = polygon.title?.uppercased(),
//                  let risk = titleToRisk[title] else { return nil }
//            
//            return (risk, polygon)
//        }
//        
//        return matchingPolygons
//            .filter { PolygonHelpers.isUserIn(user: locationProvider.resolvedUserLocation, mkPolygons: [$0.1]).0 }
//            .map { $0.0 }
//            .max() ?? .allClear
//    }
//    
//    var severeRisk: SevereWeatherThreat {
//        let severePolygons: [(SevereWeatherThreat, MKMultiPolygon)] = [
//            (.wind(probability: 0), MKMultiPolygon(spcProvider.wind.flatMap {$0.polygons})),
//            (.hail(probability: 0), MKMultiPolygon(spcProvider.hail.flatMap {$0.polygons})),
//            (.tornado(probability: 0), MKMultiPolygon(spcProvider.tornado.flatMap {$0.polygons})),
//        ]
//        
//        return severePolygons
//            .compactMap { baseThreat, polygon in
//                let (isInPolygon, probability) =
//                PolygonHelpers.isUserIn(user: locationProvider.resolvedUserLocation, mkPolygons: polygon.polygons)
//                return isInPolygon ? baseThreat.with(probability: probability) : nil
//            }
//            .max(by: {$0.priority < $1.priority}) ?? .allClear
//    }
//}

#Preview {
    let mock = LocationManager()
    let spc = SpcProvider.previewData
    SummaryBadgeView()
        .environment(mock)
        .environment(spc)
        .environment(SummaryProvider(provider: spc, location: mock))
}
