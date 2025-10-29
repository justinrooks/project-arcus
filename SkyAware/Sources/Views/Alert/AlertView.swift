//
//  AlertView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI
import SwiftData

struct AlertView: View {
//    @Environment(SpcProvider.self) private var provider: SpcProvider
    @Environment(\.modelContext) private var modelContext
    
    private let scale: Double = 0.9
    
    @Query private var mesos: [MD]
    @Query private var watches: [WatchModel]
    
    var body: some View {
        List {
            if(watches.isEmpty && mesos.isEmpty){
                ContentUnavailableView("No active watches or mesos",
                    systemImage: "checkmark.seal.fill")
                .scaleEffect(scale)
            } else {
                if(watches.isEmpty) {
                    ContentUnavailableView("No active watches",
                                           systemImage: "checkmark.seal.fill")
                    .scaleEffect(scale)
                } else {
                    Section(header: Text("Watches")) {
                        ForEach(watches) { watch in
                            NavigationLink(destination: WatchDetailView(watch: watch)) {
                                AlertRowView(alert: watch)
                            }
                        }
                        .onDelete(perform: { indexSet in
                            indexSet.forEach { index in
                                let watch = watches[index]
                                modelContext.delete(watch)
                            }
                        })
                    }
                }
                
                if(mesos.isEmpty) {
                    ContentUnavailableView("No active mesoscale discussions",
                                           systemImage: "checkmark.seal.fill")
                    .scaleEffect(scale)
                } else {
                    Section(header: Text("Mesoscale Discussions")) {
                        ForEach(mesos) { meso in
                            NavigationLink(destination: MesoscaleDiscussionCard(meso: meso)) {
                                AlertRowView(alert: meso)
                            }
                        }
                        .onDelete(perform: { indexSet in
                            indexSet.forEach { index in
                                let meso = mesos[index]
                                modelContext.delete(meso)
                            }
                        })
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Active Alerts")
        .refreshable {
            Task {
                print("Refreshing Alerts")
//                try await provider.fetchMesoDiscussions()
//                try await provider.fetchWatches()
            }
        }
    }
}

#Preview {
    let preview = Preview(MD.self, WatchModel.self)
    preview.addExamples(MD.sampleDiscussions)
    preview.addExamples(WatchModel.sampleWatches)
//    let provider = SpcProvider(client: SpcClient(),
//                               autoLoad: false)
    
    return NavigationStack {
        AlertView()
            .modelContainer(preview.container)
//            .environment(provider)
    }
}
