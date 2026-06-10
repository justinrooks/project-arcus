//
//  AlertView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

struct AlertView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let focusedAlertRequest: RemoteAlertFocusRequest?
    let onRefresh: (() async -> Void)?
    let onFocusedAlertRequestHandled: ((RemoteAlertFocusRequest.ID) -> Void)?
    
    @State private var selectedAlert: AlertDTO?
    
    private var hasNoAlerts: Bool {
        alerts.isEmpty && mesos.isEmpty
    }
    
    private var sortedAlerts: [AlertDTO] {
        alerts.sorted { lhs, rhs in
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
        (alerts.map(\.issued) + mesos.map(\.issued)).max()
    }
    
    private var totalAlertCount: Int {
        alerts.count + mesos.count
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }
    
    private var activeLocalAlertLabel: String {
        "\(totalAlertCount) active local \(totalAlertCount == 1 ? "alert" : "alerts")"
    }
    
    init(
        mesos: [MdDTO],
        alerts: [AlertDTO],
        focusedAlertRequest: RemoteAlertFocusRequest? = nil,
        onRefresh: (() async -> Void)? = nil,
        onFocusedAlertRequestHandled: ((RemoteAlertFocusRequest.ID) -> Void)? = nil
    ) {
        self.mesos = mesos
        self.alerts = alerts
        self.focusedAlertRequest = focusedAlertRequest
        self.onRefresh = onRefresh
        self.onFocusedAlertRequestHandled = onFocusedAlertRequestHandled
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                overviewCard
                
                if sortedAlerts.isEmpty == false {
                    alertSection(
                        title: "Alerts",
                        subtitle: "\(alerts.count) active",
                        symbol: "exclamationmark.triangle.fill"
                    ) {
                        ForEach(sortedAlerts) { alert in
                            NavigationLink {
                                alertDetail(for: alert)
                            } label: {
                                AlertRowView(alert: alert)
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
                            .accessibilityIdentifier("alert-center-watch-row-\(alert.id)")
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
                            NavigationLink {
                                mesoDetail(for: meso)
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
        .task(id: focusedAlertRequest?.id) {
            guard let focusedAlertRequest, let focusedAlert = focusedAlertRequest.alert else { return }
            selectedAlert = focusedAlert
            onFocusedAlertRequestHandled?(focusedAlertRequest.id)
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedAlert) { alert in
            alertDetail(for: alert)
        }
    }

    private func alertDetail(for alert: AlertDTO) -> some View {
        ScrollView {
            AlertDetailView(alert: alert, layout: .full)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .accessibilityIdentifier("alert-center-watch-detail-view")
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        .navigationTitle("Weather Alert")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
    }

    private func mesoDetail(for meso: MdDTO) -> some View {
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
        
        if sortedAlerts.isEmpty {
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
            if adaptiveLayout.usesAccessibilityLayout {
                Label(title, systemImage: symbol)
                    .font(.headline.weight(.semibold))
            } else {
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
        AlertView(mesos: MD.sampleDiscussionDTOs, alerts: Watch.sampleWatchRows)
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
