//
//  AlertView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI
import SwiftData

struct AlertView: View {
    @Environment(SpcProvider.self) private var provider: SpcProvider
    @Environment(\.modelContext) private var modelContext
    
    @Query private var mesos: [MD]
    
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

            if(mesos.isEmpty) {
                ContentUnavailableView("No active mesoscale discussions",
                   systemImage: "sun.horizon.fill")
            } else {
                Section(header: Text("Mesoscale Discussions")) {
                    ForEach(mesos) { meso in
                        NavigationLink(destination: MesoscaleDiscussionCard(meso: meso)) {
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
            Task {
                print("Refreshing Alerts")
                try await provider.fetchMesoDiscussions()
            }
        }
    }
}

#Preview {
    let preview = Preview(MD.self)
    preview.addExamples(MD.sampleDiscussions)
    let provider = SpcProvider(client: SpcClient(),
                               container: preview.container,
                               autoLoad: false)
    
    return NavigationStack {
        AlertView()
            .modelContainer(preview.container)
            .environment(provider)
    }
}
