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
            if watches.isEmpty && mesos.isEmpty {
                ContentUnavailableView {
                    Label("No active watches or mesos", systemImage: "checkmark.seal.fill")
                } description: {
                    Text("There are no active weather watches.")
                }
                .scaleEffect(scale)
                .listRowBackground(Color.clear)
            } else {
                if watches.isEmpty {
                    ContentUnavailableView {
                        Label("No active watches", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("There are no active weather watches.")
                    }
                    .scaleEffect(scale)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(watches) { watch in
                            AlertRowView(alert: watch)
                                .contentShape(Rectangle()) // Makes entire row tappable
                                .onTapGesture {
                                    selectedWatch = watch
                                }
                                .padding(.horizontal, 2)
                        }
                    } header: {
                        Text("Watches")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                    }
                }
                
                if mesos.isEmpty {
                    ContentUnavailableView {
                        Label("No active mesoscale discussions", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("There are no active mesoscale discussions.")
                    }
                    .scaleEffect(scale)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(mesos) { meso in
                            AlertRowView(alert: meso)
                                .contentShape(Rectangle()) // Makes entire row tappable
                                .onTapGesture {
                                    selectedMeso = meso
                                }
                                .padding(.horizontal, 2)
                        }
                    } header: {
                        Text("Mesoscale Discussions")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
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
