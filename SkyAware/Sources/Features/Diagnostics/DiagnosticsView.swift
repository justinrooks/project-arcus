//
//  DiagnosticsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/10/25.
//

import SwiftUI

struct DiagnosticsView: View {
    var body: some View {
        List {
            Section("Location") {
//                Text("Current: \(currentLocation)")
//                Text("Last Update: \(lastLocationUpdate)")
//                Text("Authorization: \(locationAuthStatus)")
            }
            
            Section("Data Sources") {
//                Text("WeatherKit: \(weatherKitStatus)")
//                Text("SPC: \(spcStatus)")
//                Text("NWS: \(nwsStatus)")
            }
            
            Section("Storage") {
//                Text("Outlooks Cached: \(cachedOutlooks)")
//                Text("Mesos Cached: \(cachedMesos)")
            }
            
            Section("Actions") {
                Button("Clear Cache") {
//                    clearCache()
                }
                .skyAwareGlassButtonStyle()
                Button("Force Refresh") {
//                    forceRefresh()
                }
                .skyAwareGlassButtonStyle(prominent: true)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView()
            .navigationTitle("Diagnostic Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
