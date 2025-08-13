//
//  SummaryHeaderView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI

struct SummaryHeaderView: View {
    @Environment(LocationManager.self) private var locationProvider: LocationManager
    var body: some View {
        // Header
        FreshnessView()
        Label(locationProvider.locale, systemImage: "location")
            .fontWeight(.medium)
    }
}

#Preview {
    SummaryHeaderView()
        .environment(LocationManager())
}
