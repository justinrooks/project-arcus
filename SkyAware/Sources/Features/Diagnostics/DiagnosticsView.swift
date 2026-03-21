//
//  DiagnosticsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/10/25.
//

import SwiftUI
import OSLog

struct DiagnosticsView: View {
    @State private var cacheStatusMessage: String?
    private let logger = Logger.uiSettings

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
                    clearCache()
                }
                .skyAwareGlassButtonStyle()

                if let cacheStatusMessage {
                    Text(cacheStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Force Refresh") {
//                    forceRefresh()
                }
                .skyAwareGlassButtonStyle(prominent: true)
                .disabled(true)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheStatusMessage = "Network cache cleared. Your next fetch should be live."
        logger.notice("Diagnostics cleared shared URL cache")
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
