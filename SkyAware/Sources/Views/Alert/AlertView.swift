//
//  AlertView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI
import SwiftData

struct AlertView: View {
    @Environment(\.modelContext) private var modelContext
    
    private let scale: Double = 0.9
    
    // TODO: These need to come from the parent
    @Query private var mesos: [MD]
    @Query private var watches: [WatchModel]
    
    @State private var selectedWatch: WatchModel?
    @State private var selectedMeso: MD?
    
    var body: some View {
        List {
            if(watches.isEmpty && mesos.isEmpty){
                ContentUnavailableView {
                    Label("No active watches or mesos", systemImage: "checkmark.seal.fill")
                } description: {
                    Text("There are no active weather watches.")
                }
                .scaleEffect(scale)
            } else {
                if(watches.isEmpty) {
                    ContentUnavailableView {
                        Label("No active watches", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("There are no active weather watches.")
                    }
                    .scaleEffect(scale)
                } else {
                    Section(header: Text("Watches")) {
                        ForEach(watches) { watch in
                            AlertRowView(alert: watch)
                                .contentShape(Rectangle()) // Makes entire row tappable
                                .onTapGesture {
                                    selectedWatch = watch
                                }
                                .padding(.horizontal)
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
                    ContentUnavailableView {
                        Label("No active mesoscale discussions", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("There are no active mesoscale discussions.")
                    }
                    .scaleEffect(scale)
                } else {
                    Section(header: Text("Mesoscale Discussions")) {
                        ForEach(mesos) { meso in
                            AlertRowView(alert: meso)
                                .contentShape(Rectangle()) // Makes entire row tappable
                                .onTapGesture {
                                    selectedMeso = meso
                                }
                                .padding(.horizontal)
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
        .navigationDestination(item: $selectedWatch) { watch in
            #warning("TODO: Need to get real DTOs here")
            let tempDto = WatchDTO(
                number: watch.number,
                title: watch.title,
                link: watch.link,
                issued: watch.issued,
                validStart: watch.validStart,
                validEnd: watch.validEnd,
                summary: watch.summary,
                type: "Tornado"
            )
            
            ScrollView {
                WatchDetailView(watch: tempDto, layout: .full)
            }
            .navigationTitle("Weather Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
        }
        .navigationDestination(item: $selectedMeso) { meso in
            // TODO: Need to get a MdDTO here to pass to the discussion card.
            #warning("TODO: Need to get real DTOs here")
            let tempDto = MdDTO(number: meso.number,
                                title: meso.title,
                                link: meso.link,
                                issued: meso.issued,
                                validStart: meso.validStart,
                                validEnd: meso.validEnd,
                                areasAffected: meso.areasAffected,
                                summary: meso.summary,
                                watchProbability: meso.watchProbability,
                                threats: meso.threats ?? nil,
                                coordinates:meso.coordinates
            )
            ScrollView {
                MesoscaleDiscussionCard(meso: tempDto, layout: .full)
//                    .padding(.horizontal, 16)
//                    .padding(.top, 16)
            }
            .navigationTitle("Mesoscale Discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
        }
        .contentMargins(.top, 0, for: .scrollContent)
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
    
    return NavigationStack {
        AlertView()
            .modelContainer(preview.container)
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
