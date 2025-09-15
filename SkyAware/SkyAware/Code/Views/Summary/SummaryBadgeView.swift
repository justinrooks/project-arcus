//
//  SummaryBadgeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI
import MapKit

struct SummaryBadgeView: View {
    @Environment(SummaryProvider.self) private var summary: SummaryProvider
    
    var body: some View {
        // Badges
        HStack {
            StormRiskBadgeView(level: summary.getStormRisk())
            Spacer()
            SevereWeatherBadgeView(threat: summary.getSevereRisk())
        }
        .padding(.vertical, 5)
//            .fixedSize(horizontal: true, vertical: true)
    }
}

#Preview {
    let mock = LocationManager()
    let spc = SpcProvider.previewData
    SummaryBadgeView()
        .environment(SummaryProvider(provider: spc, location: mock))
}
