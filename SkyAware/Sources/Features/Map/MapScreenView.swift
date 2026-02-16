//
//  MapScreenView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import MapKit
import OSLog

struct MapScreenView: View {
    @Environment(\.dependencies) private var deps
    private let logger = Logger.uiMap
    private let polygonMapper = MapPolygonMapper()
    
    // MARK: Local handles
    private var svc: any SpcMapData { deps.spcMapData }
    private var loc: LocationClient { deps.locationClient }
    
    @State private var selected: MapLayer = .categorical
    @State private var showLayerPicker = false
    
    @State private var mesos: [MdDTO] = []
    @State private var stormRisk: [StormRiskDTO] = []
    @State private var severeRisks: [SevereRiskShapeDTO] = []
    @State private var fireRisk: [FireRiskDTO] = []
    @State private var activePolygons = MKMultiPolygon([])
    @State private var snap: LocationSnapshot?
    
    var body: some View {
        ZStack {
            MapCanvasView(polygons: activePolygons, coordinates: snap?.coordinates)
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
        .task {
            await loadMapData()
        }
        .onChange(of: selected) { _, _ in
            rebuildPolygons()
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
    
    @MainActor
    private func loadMapData() async {
        async let severeTask = fetchSevereRiskShapes()
        async let stormTask = fetchStormRiskShapes()
        async let mesoTask = fetchMesoShapes()
        async let fireTask = fetchFireRiskShapes()

        let (severeResult, stormResult, mesoResult, fireResult) = await (severeTask, stormTask, mesoTask, fireTask)

        switch severeResult {
        case .success(let data):
            severeRisks = data
        case .failure(let error):
            logger.error("Failed to load severe risk map data: \(error.localizedDescription, privacy: .public)")
        }

        switch stormResult {
        case .success(let data):
            stormRisk = data
        case .failure(let error):
            logger.error("Failed to load categorical map data: \(error.localizedDescription, privacy: .public)")
        }

        switch mesoResult {
        case .success(let data):
            mesos = data
        case .failure(let error):
            logger.error("Failed to load mesoscale map data: \(error.localizedDescription, privacy: .public)")
        }
        
        switch fireResult {
        case .success(let data):
            fireRisk = data
        case .failure(let error):
            logger.error("Failed to load fire map data: \(error.localizedDescription, privacy: .public)")
        }

        rebuildPolygons()
    }

    private func fetchSevereRiskShapes() async -> Result<[SevereRiskShapeDTO], any Error> {
        do {
            return .success(try await svc.getSevereRiskShapes())
        } catch {
            return .failure(error)
        }
    }

    private func fetchStormRiskShapes() async -> Result<[StormRiskDTO], any Error> {
        do {
            return .success(try await svc.getStormRiskMapData())
        } catch {
            return .failure(error)
        }
    }

    private func fetchMesoShapes() async -> Result<[MdDTO], any Error> {
        do {
            return .success(try await svc.getMesoMapData())
        } catch {
            return .failure(error)
        }
    }
    
    private func fetchFireRiskShapes() async -> Result<[FireRiskDTO], any Error> {
        do {
            return .success(try await svc.getFireRisk())
        } catch {
            return .failure(error)
        }
    }

    @MainActor
    private func rebuildPolygons() {
        activePolygons = polygonMapper.polygons(
            for: selected,
            stormRisk: stormRisk,
            severeRisks: severeRisks,
            mesos: mesos,
            fires: fireRisk
        )
    }
}

#Preview {
    MapScreenView()
}
