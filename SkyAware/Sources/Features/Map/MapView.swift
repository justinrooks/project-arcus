//
//  MapView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @Environment(\.dependencies) private var deps
    
    // MARK: Local handles
    private var svc: any SpcMapData { deps.spcMapData }
    private var loc: LocationClient { deps.locationClient }
    
    @State private var selected: MapLayer = .categorical
    @State private var showLayerPicker = false
    
    @State private var mesos: [MdDTO] = []
    @State private var stormRisk: [StormRiskDTO] = []
    @State private var severeRisks: [SevereRiskShapeDTO] = []
    @State private var snap: LocationSnapshot?
    
    var body: some View {
        ZStack {
            CONUSMapView(polygonList: polygonsForLayer(named: selected), coordinates: snap?.coordinates)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Button {
                    showLayerPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .padding()
                }
                .buttonStyle(.plain)
                .background(.ultraThickMaterial, in: Circle())
                .padding(26)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            
            // Legend in bottom-right (stable container)
            VStack {
                Spacer()
                Group {
                    MapLegend(layer: selected, probabilities: severeProbabilitiesForSelectedLayer())
                }
                .transition(.opacity)
                .animation(.default, value: selected)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous))
                .padding([.bottom, .trailing])
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .sheet(isPresented: $showLayerPicker) {
            LayerPickerSheet(selection: $selected,
                             title: "Map Layers")
        }
        .onAppear {
            Task {
                do {
                    severeRisks = try await svc.getSevereRiskShapes()
                    stormRisk = try await svc.getStormRiskMapData()
                    mesos = try await svc.getMesoMapData()
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        .task {
            if let first = await loc.snapshot() {
                await MainActor.run { snap = first }
            }
            
            let stream = await loc.updates()
            for await s in stream {
                await MainActor.run { snap = s }
            }
        }
    }
    
    private func severeProbabilitiesForSelectedLayer() -> [ThreatProbability]? {
        switch selected {
        case .tornado: return getProbability(for: .tornado)
        case .hail:    return getProbability(for: .hail)
        case .wind:    return getProbability(for: .wind)
        default:       return nil
        }
    }
    
    private func getProbability(for type:ThreatType) -> [ThreatProbability] {
        severeRisks.filter { $0.type == type }
            .compactMap { $0.probabilities }
            .sorted { $0.intValue < $1.intValue }
    }
    
    // Helper to build MKPolygons from arbitrary sources
    private func makeMKPolygons<Element>(
        from source: [Element],
        coordinates: (Element) -> [CLLocationCoordinate2D],
        title: (Element) -> String?
    ) -> [MKPolygon] {
        source.map { element in
            let coords = coordinates(element)
            let mkPolygon = MKPolygon(coordinates: coords, count: coords.count)
            mkPolygon.title = title(element)
            return mkPolygon
        }
    }
    
    private func polygonsForLayer(named layer: MapLayer) -> MKMultiPolygon {
        switch layer {
        case .categorical:
            let source = stormRisk.flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case .tornado:
            //            return MKMultiPolygon(provider.tornado.flatMap {$0.polygons})
            let source = severeRisks
                .filter { $0.type == .tornado }
                .flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case .hail:
            let source = severeRisks
                .filter { $0.type == .hail }
                .flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case .wind:
            let source = severeRisks
                .filter { $0.type == .wind }
                .flatMap { $0.polygons }
            let polygons = makeMKPolygons(
                from: source,
                coordinates: { $0.ringCoordinates },
                title: { $0.title }
            )
            return MKMultiPolygon(polygons)
        case .meso:
            let polygons = makeMKPolygons(
                from: mesos,
                coordinates: { $0.coordinates.map { $0.location } },
                title: { _ in layer.key }
            )
            return MKMultiPolygon(polygons)
        }
    }
}

#Preview {
    MapView()
}

