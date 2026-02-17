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
    @State private var selectedSevereRisks: [SevereRiskShapeDTO]? = nil
    @State private var fireRisk: [FireRiskDTO] = []
    @State private var activePolygons = MKMultiPolygon([])
    @State private var snap: LocationSnapshot?
    @Namespace private var layerNamespace
    
    var body: some View {
        ZStack {
            MapCanvasView(polygons: activePolygons, coordinates: snap?.coordinates)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .trailing) {
                HStack(spacing: 10) {
                    Label(selected.title, systemImage: selected.symbol)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .skyAwareSurface(
                            cornerRadius: 16,
                            tint: .white.opacity(0.10),
                            shadowOpacity: 0.12,
                            shadowRadius: 8,
                            shadowY: 3
                        )

                    Button {
                        showLayerPicker = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Map layers")
                    .skyAwareSurface(
                        cornerRadius: 22,
                        tint: .skyAwareAccent.opacity(0.18),
                        interactive: true,
                        shadowOpacity: 0.16,
                        shadowRadius: 10,
                        shadowY: 6
                    )
                    .modifier(MapLayerButtonMorph(namespace: layerNamespace))
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(3)
            
            // Legend in bottom-right (stable container)
            VStack {
                Spacer()
                Group {
                    MapLegend(layer: selected, severeRisks: selectedSevereRisks, fireRisks: fireRisk)
                }
                .transition(.opacity)
                .animation(.default, value: selected)
                .padding([.bottom, .trailing])
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $showLayerPicker) {
            LayerPickerSheet(selection: $selected,
                             title: "Map Layers",
                             triggerNamespace: layerNamespace)
        }
        .task {
            await loadMapData()
        }
        .onChange(of: selected) { _, _ in
            rebuildMapState()
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
    
    private func severeRisksForSelectedLayer(for layer: MapLayer) -> [SevereRiskShapeDTO]? {
        let sortedSevereRisks: [SevereRiskShapeDTO]
        switch layer {
        case .tornado:
            sortedSevereRisks = severeRisksForType(.tornado)
        case .hail:
            sortedSevereRisks = severeRisksForType(.hail)
        case .wind:
            sortedSevereRisks = severeRisksForType(.wind)
        default:
            return nil
        }
        return sortedSevereRisks
    }

    private func severeRisksForType(_ type: ThreatType) -> [SevereRiskShapeDTO] {
        severeRisks
            .filter { $0.type == type }
            .sorted { $0.probabilities.intValue < $1.probabilities.intValue }
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

        rebuildMapState()
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
    private func rebuildMapState() {
        activePolygons = polygonMapper.polygons(
            for: selected,
            stormRisk: stormRisk,
            severeRisks: severeRisks,
            mesos: mesos,
            fires: fireRisk
        )
        selectedSevereRisks = severeRisksForSelectedLayer(for: selected)
    }
}

private struct MapLayerButtonMorph: ViewModifier {
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffectID("map-layer-button", in: namespace)
        } else {
            content
        }
    }
}

#Preview {
    MapScreenView()
}
