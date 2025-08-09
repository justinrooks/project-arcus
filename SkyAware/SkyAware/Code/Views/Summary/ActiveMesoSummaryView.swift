//
//  ActiveMesoSummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import SwiftUI

struct ActiveMesoSummaryView: View {
    @State private var viewModel: SummaryViewModel
    @State private var selectedMeso: MesoscaleDiscussion? = nil
    
    init(viewModel: SummaryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        GroupBox {
            let mesos: [MesoscaleDiscussion] = Array(viewModel.mesosNearby.prefix(3))
            Divider()
            if mesos.isEmpty {
                HStack {
                    Text("No active mesos in your area")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(mesos) { meso in
                        Button { selectedMeso = meso } label: { MesoRowView(meso: meso) }
                            .buttonStyle(.plain)
                        
                        if meso.number != mesos.last?.number { Divider() }
                    }
                }
            }
        } label: {
            Label("Active Mesos Nearby", systemImage: "cloud.bolt.rain.fill")
                .foregroundColor(.teal)
        }
        .sheet(item: $selectedMeso) { meso in
            VStack {
                ScrollView {
                    MesoscaleDiscussionCard(vm: MesoscaleDiscussionViewModel(md: meso), layout: .sheet)
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

private struct MesoRowView: View {
    let meso: MesoscaleDiscussion
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ThreatIconsCol(threats: meso.threats)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
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
            
            Text("Ends: \(meso.validEnd, style: .time)")
                .monospacedDigit()
                .font(.footnote)
                .foregroundStyle(.secondary)
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
            slot("cloud.hail", show: showHail)
            slot("tornado", show: showTornado)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 15, alignment: .leading) // fixed cluster width for perfect alignment
    }
}

#Preview {
    let mock = LocationManager()
    let spc = SpcProvider.previewData
    ActiveMesoSummaryView(viewModel: SummaryViewModel(provider: spc, locationProvider: mock))
}
