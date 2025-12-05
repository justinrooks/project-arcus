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
    @State private var sheetHeight: CGFloat = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Header
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.skyAwareAccent)
                Text("Local Alerts")
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
        .cardBackground()
        .sheet(item: $selectedMeso) { meso in
            NavigationStack {
                ScrollView {
                    MesoscaleDiscussionCard(meso: meso, layout: .sheet)
                        .padding(.top, 8)
                        .padding(.horizontal, 6)
                }
                .background(.skyAwareBackground)
                .getHeight(for: $sheetHeight)
                .presentationDetents([.height(sheetHeight)])
//                .presentationDetents([.medium, .large])
                //            .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
//                .navigationTitle("Mesoscale Discussion")
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
                .getHeight(for: $sheetHeight)
                .presentationDetents([.height(sheetHeight)])
//                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
//                .navigationTitle("Watch")
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
            Image(systemName: "waveform.path.ecg.magnifyingglass")
//                .font(.subheadline)
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
                Text("Expires: \(meso.validEnd, style: .time)")
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
//                .font(.subheadline)
                .foregroundStyle(watch.type == "Tornado" ? Color.tornadoRed : Color.severeTstormWarn)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(watch.type) \(watch.number.formatted(.number.grouping(.never)))")
                    .font(.subheadline.weight(.semibold))
                Text("Western Kansas, Southwest Nebraska - TBD")
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            VStack(alignment: .trailing) {
                Text("Expires: \(watch.validEnd, style: .time)")
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActiveAlertSummaryView(mesos: MD.sampleDiscussionDTOs, watches: WatchModel.sampleWatcheDtos)
            .toolbar(.hidden, for: .navigationBar)
            .background(.skyAwareBackground)
    }
}

