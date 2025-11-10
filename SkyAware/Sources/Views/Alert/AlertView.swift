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
    
    // TODO: These need to come from the parent
    @Query private var mesos: [MD]
    @Query private var watches: [WatchModel]
    
    @State private var selectedWatch: WatchModel?
    @State private var selectedMeso: MD?
    
    var body: some View {
        List {
            if(watches.isEmpty && mesos.isEmpty){
                ContentUnavailableView("No active watches or mesos",
                    systemImage: "checkmark.seal.fill")
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
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listSectionSpacing(10)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                if(mesos.isEmpty) {
                    ContentUnavailableView("No active mesoscale discussions",
                                           systemImage: "checkmark.seal.fill")
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
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listSectionSpacing(10)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .navigationDestination(item: $selectedWatch) { watch in
            WatchDetailView(watch: watch)
        }
        .navigationDestination(item: $selectedMeso) { meso in
            // TODO: Need to get a MdDTO here to pass to the discussion card.
            //            MesoscaleDiscussionCard(meso: meso)
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(15)
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        
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
//    let provider = SpcProvider(client: SpcClient(),
//                               autoLoad: false)
    
    return NavigationStack {
        AlertView()
            .modelContainer(preview.container)
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.inline)
//            .toolbarBackground(.visible, for: .navigationBar)      // <- non-translucent
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
//            .environment(provider)
    }
}
