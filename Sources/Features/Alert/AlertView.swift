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
        AlertPresentationOrdering.ordered(alerts, endDate: \.ends)
    }
    
    private var sortedMesos: [MdDTO] {
        AlertPresentationOrdering.ordered(mesos, endDate: \.validEnd)
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
        List {
            Section {
                overviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if sortedAlerts.isEmpty == false {
                Section {
                    ForEach(sortedAlerts) { alert in
                        alertNavigationRow(
                            identifier: "alert-center-watch-row-\(alert.id)",
                            destination: {
                                alertDetail(for: alert)
                            }
                        ) {
                            AlertRowView(alert: alert)
                        }
                    }
                } header: {
                    alertSectionHeader(
                        title: "Alerts",
                        subtitle: "\(alerts.count) active",
                        symbol: "exclamationmark.triangle.fill"
                    )
                }
            }

            if sortedMesos.isEmpty == false {
                Section {
                    ForEach(sortedMesos) { meso in
                        alertNavigationRow(
                            identifier: "alert-center-meso-row-\(meso.id)",
                            destination: {
                                mesoDetail(for: meso)
                            }
                        ) {
                            AlertRowView(alert: meso)
                        }
                    }
                } header: {
                    alertSectionHeader(
                        title: "Mesoscale Discussions",
                        subtitle: "\(mesos.count) active",
                        symbol: "waveform.path.ecg"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(15)
        .scrollContentBackground(.hidden)
        .navigationLinkIndicatorVisibility(.hidden)
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
        .contentMargins(.top, 0, for: .scrollContent)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedAlert) { alert in
            alertDetail(for: alert)
        }
    }

    private func alertNavigationRow<Destination: View, RowContent: View>(
        identifier: String,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> RowContent
    ) -> some View {
        NavigationLink(destination: destination) {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .cardRowBackground(
            cornerRadius: SkyAwareRadius.row,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                hasNoAlerts ? "No active alerts" : activeLocalAlertLabel,
                systemImage: hasNoAlerts ? "bell" : "bolt.badge.clock"
            )
            .symbolVariant(.fill)
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
        
        return "Warnings are shown before watches, then mesoscale discussions. Within each group, items that end sooner are surfaced first."
    }

    @ViewBuilder
    private func alertSectionHeader(
        title: String,
        subtitle: String,
        symbol: String
    ) -> some View {
        if adaptiveLayout.usesAccessibilityLayout {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
                .textCase(nil)
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
            .textCase(nil)
        }
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

#Preview("Empty") {
    NavigationStack {
        AlertView(mesos: [], alerts: [])
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

#Preview("Accessibility") {
    NavigationStack {
        AlertView(mesos: MD.sampleDiscussionDTOs, alerts: Watch.sampleWatchRows)
            .environment(\.dynamicTypeSize, .accessibility3)
            .navigationTitle("Active Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
