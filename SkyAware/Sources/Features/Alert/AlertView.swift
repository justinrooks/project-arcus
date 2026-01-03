//
//  AlertView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

struct AlertView: View {
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
    
    @State private var selectedWatch: WatchRowDTO?
    @State private var selectedMeso: MdDTO?
    
    private let scale: Double = 0.9
    
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
//                        .onDelete(perform: { indexSet in
//                            indexSet.forEach { index in
//                                let watch = watches[index]
//                                modelContext.delete(watch)
//                            }
//                        })
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
                    }
                }
            }
        }
        .navigationDestination(item: $selectedWatch) { watch in
            ScrollView {
                WatchDetailView(watch: watch, layout: .full)
            }
            .navigationTitle("Weather Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
        }
        .navigationDestination(item: $selectedMeso) { meso in
            ScrollView {
                MesoscaleDiscussionCard(meso: meso, layout: .full)
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
    }
}

#Preview {
    NavigationStack {
        AlertView(mesos: MD.sampleDiscussionDTOs, watches: Watch.sampleWatchRows)
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
