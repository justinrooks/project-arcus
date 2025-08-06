//
//  AlertView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

struct AlertView: View {
    @Environment(SpcProvider.self) private var provider: SpcProvider
    
    var body: some View {
        List {
            if !provider.watches.isEmpty {
                Section(header: Text("Watches")) {
                    ForEach(provider.watches) { watch in
                        NavigationLink(destination: WatchDetailView(watch: watch)) {
                            AlertRowView(alert: watch)
                        }
                        .foregroundStyle(Color.clear)
//                        .listRowInsets(EdgeInsets()) // Optional: tighten spacing
//                        .listRowSeparator(.hidden)  // Or `.hidden` if you want a cleaner card look
                    }
                }
            }

            if !provider.meso.isEmpty {
                Section(header: Text("Mesoscale Discussions")) {
                    ForEach(provider.meso) { meso in
                        NavigationLink(destination: MesoDetailView(discussion: meso)) {
                            AlertRowView(alert: meso)
                        }
                        .foregroundStyle(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Nearby Alerts")
        .refreshable {
            print("Refreshing SPC Data")
            fetchSpcData()
        }
    }
}

extension AlertView {
    func fetchSpcData() {
        provider.loadFeed()
        
        print("Got SPC Feed data")
    }
}

#Preview {
    AlertView()
        .environment(SpcProvider.previewData)
}
