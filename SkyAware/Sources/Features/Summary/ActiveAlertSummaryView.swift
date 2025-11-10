//
//  ActiveAlertSummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import SwiftUI

struct ActiveAlertSummaryView: View {
    let mesos: [MdDTO]

    @State private var selectedMeso: MdDTO? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")//"cloud.bolt.rain.fill")
                    .foregroundColor(.skyAwareAccent)
                Text("Active Alerts Nearby")
                    .font(.headline)
                    .foregroundColor(.skyAwareAccent)
                Spacer()
            }
            
            // MARK: Active Alerts
            VStack(spacing: 8) {
                ForEach(mesos) { meso in
                    Button { selectedMeso = meso } label: { MesoRowView(meso: meso) }
                        .buttonStyle(.plain)
                    
                    if meso.number != mesos.last?.number { Divider() }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.cardBackground)
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
        )
        .sheet(item: $selectedMeso) { meso in
            VStack {
                ScrollView {
                    MesoscaleDiscussionCard(meso: meso,
                                            layout: .sheet)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 25)
                    Spacer()
                }
            }
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackground(.regularMaterial)
        }
    }
}

// MARK: Components
private struct MesoRowView: View {
    let meso: MdDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            if let threats = meso.threats {
                ThreatIconsCol(threats: threats)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("MD \(meso.number.formatted(.number.grouping(.never)))")
                    .fontWeight(.medium)
                Text(meso.areasAffected.isEmpty ? meso.title : meso.areasAffected)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            VStack(alignment: .leading) {
                Text("Ends: \(meso.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Watch Probability: \(meso.watchProbability)%")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThreatIconsCol: View {
    let showWind: Bool
    let showHail: Bool
    let showTornado: Bool
    
    init(threats: MDThreats) {
        self.showWind = threats.peakWindMPH != nil
        self.showHail = threats.hailRangeInches != nil
        if let ts = threats.tornadoStrength, !ts.isEmpty {
            self.showTornado = true
        } else {
            self.showTornado = false
        }
    }
    
    @ViewBuilder
    private func slot(_ name: String, show: Bool) -> some View {
        if show {
            Image(systemName: name)
        } else {
            Image(systemName: name).hidden() // reserve space for alignment
        }
    }
    
    var body: some View {
        VStack(spacing: 5) {
            slot("wind", show: showWind)
            slot("cloud.hail.fill", show: showHail)
            slot("tornado", show: showTornado)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 15, alignment: .leading) // fixed cluster width for perfect alignment
    }
}

#Preview {
    NavigationStack {
        ActiveAlertSummaryView(mesos: MD.sampleDiscussionDTOs)
            .toolbar(.hidden, for: .navigationBar)
            .background(.skyAwareBackground)
    }
}
