//
//  SummaryHeaderView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI

struct SummaryHeaderView: View {
    @Environment(LocationManager.self) private var locationProvider: LocationManager
//    @Environment(SpcProvider.self) private var spcProvider: SpcProvider
    
    var body: some View {
        // Header
        FreshnessView()
        
        Label(locationProvider.locale, systemImage: "location")
            .fontWeight(.medium)
//        if(spcProvider.statusMessage != nil) {
//            Text(spcProvider.statusMessage!)
//        }
    }
}

#Preview {
    let preview = Preview(ConvectiveOutlook.self)
    let mock = LocationManager()
//    let spc = SpcProvider(client: SpcClient(),
//                          autoLoad: false)
    SummaryHeaderView()
        .environment(LocationManager())
//        .environment(spc)
}
