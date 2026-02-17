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

    private var hasNoAlerts: Bool {
        watches.isEmpty && mesos.isEmpty
    }

    var body: some View {
        List {
            if hasNoAlerts {
                emptyRow(
                    title: "No active watches or mesos",
                    subtitle: "There are no active weather watches."
                )
            } else {
                if watches.isEmpty {
                    emptyRow(
                        title: "No active watches",
                        subtitle: "There are no active weather watches."
                    )
                } else {
                    Section {
                        ForEach(watches) { watch in
                            Button {
                                selectedWatch = watch
                            } label: {
                                AlertRowView(alert: watch)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        sectionHeader("Watches")
                    }
                }

                if mesos.isEmpty {
                    emptyRow(
                        title: "No active mesoscale discussions",
                        subtitle: "There are no active mesoscale discussions."
                    )
                } else {
                    Section {
                        ForEach(mesos) { meso in
                            Button {
                                selectedMeso = meso
                            } label: {
                                AlertRowView(alert: meso)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        sectionHeader("Mesoscale Discussions")
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
            }
            .navigationTitle("Mesoscale Discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
        }
        .contentMargins(.top, 0, for: .scrollContent)
    }

    @ViewBuilder
    private func emptyRow(title: String, subtitle: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "checkmark.seal.fill")
        } description: {
            Text(subtitle)
        }
        .scaleEffect(0.9)
        .listRowBackground(Color.clear)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
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
