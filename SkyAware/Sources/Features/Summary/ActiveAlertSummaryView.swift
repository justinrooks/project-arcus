//
//  ActiveAlertSummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import SwiftUI

struct ActiveAlertSummaryView: View {
    let mesos: [MdDTO]
    let watches: [WatchDTO]

    @State private var selectedMeso: MdDTO? = nil
    @State private var selectedWatch: WatchDTO? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Header
            HStack {
                Image(systemName: "exclamationmark.circle.fill")//"cloud.bolt.rain.fill")
                    .foregroundColor(.skyAwareAccent)
                Text("Active Alerts Nearby")
                    .font(.headline)
                    .foregroundColor(.skyAwareAccent)
                Spacer()
            }
            
            // MARK: Active Alerts
            VStack(alignment: .leading, spacing: 10) {
                if !watches.isEmpty {
                    Text("WATCHES")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(watches) { watch in
                        Button { selectedWatch = watch } label: { WatchRowView(watch: watch) }
                            .buttonStyle(.plain)
                        
                        if watch.number != watches.last?.number { Divider() }
                    }
                }
                
                if !mesos.isEmpty {
                    Text("MESOS")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(mesos) { meso in
                        Button { selectedMeso = meso } label: { MesoRowView(meso: meso) }
                            .buttonStyle(.plain)
                        
                        if meso.number != mesos.last?.number { Divider() }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous)
                .fill(.cardBackground)
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
        )
        .sheet(item: $selectedMeso) { meso in
            NavigationStack {
                ScrollView {
                    MesoscaleDiscussionCard(meso: meso, layout: .sheet)
                        .padding(.top, 8)
                        .padding(.horizontal, 6)
                }
                .background(.skyAwareBackground)
                .presentationDetents([.medium, .large])
                //            .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
                .navigationTitle("Mesoscale Discussion")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $selectedWatch) { watch in
            NavigationStack {
                ScrollView {
                    WatchDetailView(watch: watch, layout: .sheet)
                        .padding(.top, 8)
                        .padding(.horizontal, 6)
                }
                .background(.skyAwareBackground)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .navigationTitle("Watch")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: Components
private struct MesoRowView: View {
    let meso: MdDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
//            if let threats = meso.threats, let icon = getHighestThreat(for: threats) {
//                icon
//                    .font(.subheadline)
//                    .foregroundStyle(
//                        threats.tornadoStrength != nil && !(threats.tornadoStrength ?? "").isEmpty ? Color.tornadoRed : (
//                            threats.hailRangeInches != nil ? Color.hailBlue : Color.windTeal
//                        )
//                    )
//            } else {
//                Image(systemName: "tornado")
//                    .font(.subheadline)
//                    .foregroundStyle(Color.tornadoRed)
//            }
            Image(systemName: "waveform.path.ecg.magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(Color.mesoPurple)
            VStack(alignment: .leading, spacing: 2) {
                Text("MD \(meso.number.formatted(.number.grouping(.never)))")
                    .font(.subheadline.weight(.semibold))
                Text(meso.areasAffected.isEmpty ? meso.title : meso.areasAffected)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            VStack(alignment: .trailing) {
                Text("Prob: \(Int(meso.watchProbability))%")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Ends: \(meso.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WatchRowView: View {
    let watch: WatchDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: watch.type == "Tornado" ? "tornado" : "cloud.bolt.fill")
                .font(.subheadline)
                .foregroundStyle(watch.type == "Tornado" ? Color.tornadoRed : Color.severeTstormWarn)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(watch.type) \(watch.number.formatted(.number.grouping(.never)))")
                    .font(.subheadline.weight(.semibold))
//                Text(meso.areasAffected.isEmpty ? meso.title : meso.areasAffected)
                Text("Western Kansas, Southwest Nebraska - TBD")
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            VStack(alignment: .trailing) {
                Text("Ends: \(watch.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func getHighestThreat(for threats: MDThreats) -> Image? {
    // Highest priority: tornado > hail > wind
    let hasTornado: Bool = {
        if let ts = threats.tornadoStrength, !ts.isEmpty { return true }
        return false
    }()
    let hasHail: Bool = threats.hailRangeInches != nil
    let hasWind: Bool = threats.peakWindMPH != nil

    if hasTornado { return Image(systemName: "tornado") }
    if hasHail { return Image(systemName: "cloud.hail.fill") }
    if hasWind { return Image(systemName: "wind") }
    return nil
}

//private struct ThreatIconsCol: View {
//    let showWind: Bool
//    let showHail: Bool
//    let showTornado: Bool
//    
//    init(threats: MDThreats) {
//        self.showWind = threats.peakWindMPH != nil
//        self.showHail = threats.hailRangeInches != nil
//        if let ts = threats.tornadoStrength, !ts.isEmpty {
//            self.showTornado = true
//        } else {
//            self.showTornado = false
//        }
//    }
//    
//    @ViewBuilder
//    private func slot(_ name: String, show: Bool) -> some View {
//        if show {
//            Image(systemName: name)
//        } else {
//            Image(systemName: name).hidden() // reserve space for alignment
//        }
//    }
//    
//    var body: some View {
//        VStack(spacing: 5) {
//            slot("wind", show: showWind)
//            slot("cloud.hail.fill", show: showHail)
//            slot("tornado", show: showTornado)
//        }
//        .font(.subheadline)
//        .foregroundStyle(.secondary)
//        .frame(width: 15, alignment: .leading) // fixed cluster width for perfect alignment
//    }
//}

#Preview {
    NavigationStack {
        ActiveAlertSummaryView(mesos: MD.sampleDiscussionDTOs, watches: WatchModel.sampleWatcheDtos)
            .toolbar(.hidden, for: .navigationBar)
            .background(.skyAwareBackground)
    }
}

