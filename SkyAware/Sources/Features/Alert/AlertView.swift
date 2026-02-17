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
    let onRefresh: (() async -> Void)?

    @State private var selectedWatch: WatchRowDTO?
    @State private var selectedMeso: MdDTO?

    private var hasNoAlerts: Bool {
        watches.isEmpty && mesos.isEmpty
    }

    init(
        mesos: [MdDTO],
        watches: [WatchRowDTO],
        onRefresh: (() async -> Void)? = nil
    ) {
        self.mesos = mesos
        self.watches = watches
        self.onRefresh = onRefresh
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if hasNoAlerts {
                    emptySectionCard(
                        title: "No active watches or mesos",
                        subtitle: "There are currently no active weather watches or mesoscale discussions.",
                        symbol: "checkmark.shield"
                    )
                } else {
                    if watches.isEmpty {
                        emptySectionCard(
                            title: "No active watches",
                            subtitle: "There are no active weather watches.",
                            symbol: "checkmark.seal"
                        )
                    } else {
                        alertSection(
                            title: "Watches",
                            subtitle: "\(watches.count) active",
                            symbol: "exclamationmark.triangle.fill"
                        ) {
                            ForEach(watches) { watch in
                                Button {
                                    selectedWatch = watch
                                } label: {
                                    AlertRowView(alert: watch)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if mesos.isEmpty {
                        emptySectionCard(
                            title: "No active mesoscale discussions",
                            subtitle: "There are no active mesoscale discussions.",
                            symbol: "checkmark.seal"
                        )
                    } else {
                        alertSection(
                            title: "Mesoscale Discussions",
                            subtitle: "\(mesos.count) active",
                            symbol: "waveform.path.ecg"
                        ) {
                            ForEach(mesos) { meso in
                                Button {
                                    selectedMeso = meso
                                } label: {
                                    AlertRowView(alert: meso)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .refreshable {
            guard let onRefresh else { return }
            await onRefresh()
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedWatch) { watch in
            ScrollView {
                WatchDetailView(watch: watch, layout: .full)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
            .navigationTitle("Weather Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
        }
        .navigationDestination(item: $selectedMeso) { meso in
            ScrollView {
                MesoscaleDiscussionCard(meso: meso, layout: .full)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
            .navigationTitle("Mesoscale Discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
        }
    }

    private func alertSection<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .skyAwareChip(cornerRadius: 11, tint: .white.opacity(0.08))
            }

            content()
        }
        .padding(16)
        .cardBackground(cornerRadius: 24, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private func emptySectionCard(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground(cornerRadius: 22, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2)
    }
}

#Preview {
    NavigationStack {
        AlertView(mesos: MD.sampleDiscussionDTOs, watches: Watch.sampleWatchRows)
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
