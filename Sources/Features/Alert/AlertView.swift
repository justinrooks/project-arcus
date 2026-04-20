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
    let focusedWatchRequest: RemoteAlertFocusRequest?
    let onRefresh: (() async -> Void)?
    
    @State private var selectedMeso: MdDTO?
    @State private var selectedWatch: WatchRowDTO?
    
    private var hasNoAlerts: Bool {
        watches.isEmpty && mesos.isEmpty
    }
    
    private var sortedWatches: [WatchRowDTO] {
        watches.sorted { lhs, rhs in
            if lhs.ends != rhs.ends {
                return lhs.ends < rhs.ends
            }
            return lhs.issued > rhs.issued
        }
    }
    
    private var sortedMesos: [MdDTO] {
        mesos.sorted { lhs, rhs in
            if lhs.validEnd != rhs.validEnd {
                return lhs.validEnd < rhs.validEnd
            }
            return lhs.issued > rhs.issued
        }
    }
    
    private var latestIssued: Date? {
        (watches.map(\.issued) + mesos.map(\.issued)).max()
    }
    
    private var totalAlertCount: Int {
        watches.count + mesos.count
    }
    
    private var activeLocalAlertLabel: String {
        "\(totalAlertCount) active local \(totalAlertCount == 1 ? "alert" : "alerts")"
    }
    
    init(
        mesos: [MdDTO],
        watches: [WatchRowDTO],
        focusedWatchRequest: RemoteAlertFocusRequest? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.mesos = mesos
        self.watches = watches
        self.focusedWatchRequest = focusedWatchRequest
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                overviewCard
                
                if sortedWatches.isEmpty == false {
                    alertSection(
                        title: "Alerts",
                        subtitle: "\(watches.count) active",
                        symbol: "exclamationmark.triangle.fill"
                    ) {
                        ForEach(sortedWatches) { watch in
                            Button {
                                selectedWatch = watch
                            } label: {
                                AlertRowView(alert: watch)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(
                                SkyAwarePressableButtonStyle(
                                    cornerRadius: SkyAwareRadius.row,
                                    pressedScale: 0.988,
                                    pressedOverlayOpacity: 0.06
                                )
                            )
                        }
                    }
                }
                
                if sortedMesos.isEmpty == false {
                    alertSection(
                        title: "Mesoscale Discussions",
                        subtitle: "\(mesos.count) active",
                        symbol: "waveform.path.ecg"
                    ) {
                        ForEach(sortedMesos) { meso in
                            Button {
                                selectedMeso = meso
                            } label: {
                                AlertRowView(alert: meso)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(
                                SkyAwarePressableButtonStyle(
                                    cornerRadius: SkyAwareRadius.row,
                                    pressedScale: 0.988,
                                    pressedOverlayOpacity: 0.06
                                )
                            )
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
        .task(id: focusedWatchRequest?.id) {
            guard let focusedWatch = focusedWatchRequest?.watch else { return }
            selectedWatch = focusedWatch
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
            .navigationTitle("Weather Alert")
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
    
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                hasNoAlerts ? "Quiet right now" : activeLocalAlertLabel,
                systemImage: hasNoAlerts ? "checkmark.shield" : "bolt.badge.clock"
            )
            .font(.headline.weight(.semibold))
            
            Text(overviewMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let latestIssued {
                Text("Most recent activity: \(latestIssued.relativeDate())")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .skyAwareChip(cornerRadius: SkyAwareRadius.chipCompact, tint: .white.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }
    
    private var overviewMessage: String {
        if hasNoAlerts {
            return "SkyAware is monitoring your local area. New alerts and mesoscale discussions will appear here as soon as they are issued."
        }
        
        if sortedWatches.isEmpty {
            return "Mesoscale discussions are active for your area. Open one to check timing, concern area, and warning potential."
        }
        
        if sortedMesos.isEmpty {
            return "Weather alerts are active for your area. Open one to check timing, affected counties, and official instructions."
        }
        
        return "Open any alert for timing, impacted areas, and the full official product. Items that end sooner are surfaced first."
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
                    .skyAwareChip(cornerRadius: SkyAwareRadius.chip, tint: .white.opacity(0.08))
            }
            
            content()
        }
        .padding(16)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
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
        .cardBackground(cornerRadius: SkyAwareRadius.section, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2)
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
