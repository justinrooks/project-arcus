//
//  ActiveMesoSummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import SwiftUI
import MapKit
import SwiftData

struct ActiveMesoSummaryView: View {
    let coordinates: CLLocationCoordinate2D?
    @Environment(\.modelContext) private var modelContext
    
    @Query
    private var allMesos: [MD]
    
    @State private var selectedMeso: MD? = nil
    
    var body: some View {
        GroupBox {
            let nearBy: [MD] = Array(nearbyMesos.prefix(3))
            Divider()
            if nearBy.isEmpty {
                HStack {
                    Text("No active mesos in your area")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(nearBy) { meso in
                        Button { selectedMeso = meso } label: { MesoRowView(meso: meso) }
                            .buttonStyle(.plain)
                        
                        if meso.number != allMesos.last?.number { Divider() }
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

extension ActiveMesoSummaryView {
    var nearbyMesos: [MD] {
        return allMesos.filter {
            let coord = $0.coordinates.map { $0.location }
            let poly = MKPolygon(coordinates: coord, count: coord.count)
            guard let coordinates else { return false }
            return PolygonHelpers.inPoly(user: coordinates, polygon: poly)
        }
    }
}

private struct MesoRowView: View {
    let meso: MD
    
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
                Text("Watch Probability: \(meso.watchProbability)")
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
            slot("cloud.hail", show: showHail)
            slot("tornado", show: showTornado)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(width: 15, alignment: .leading) // fixed cluster width for perfect alignment
    }
}

//extension MesoRowView {
////    func getProbabilityString(for probability: WatchProbability) -> String {
////        return {
////            switch probability {
////            case .percent(let p): return "\(p)%"
////            case .unlikely: return "Unlikely"
////            }
////        }()
////    }
//}

#Preview {
    let preview = Preview(MD.self)
    preview.addExamples(MD.sampleDiscussions)

    return NavigationStack {
        ActiveMesoSummaryView(coordinates: .init(latitude: 39.75, longitude: -104.44))
            .modelContainer(preview.container)
    }
}
