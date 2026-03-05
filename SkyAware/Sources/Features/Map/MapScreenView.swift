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
    @State private var activeOverlays: [MKOverlay] = []
    @State private var snap: LocationSnapshot?
    @Namespace private var layerNamespace
    
    var body: some View {
        ZStack {
            MapCanvasView(polygons: activePolygons, overlays: activeOverlays, coordinates: snap?.coordinates)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .trailing) {
                HStack(spacing: 10) {
                    Button {
                        showLayerPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.2.layers.3d.top.filled")
                                .imageScale(.medium)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(selected.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 40)
                        .contentShape(Capsule())
                    }
                    .accessibilityLabel("Map layers")
                    .accessibilityValue(selected.title)
                    .scaleEffect(showLayerPicker ? 0.98 : 1)
                    .animation(.snappy(duration: 0.20), value: showLayerPicker)
                    .modifier(MapLayerPickerButtonStyle())
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
        let mappedPolygons = polygonMapper.polygons(
            for: selected,
            stormRisk: stormRisk,
            severeRisks: severeRisks,
            mesos: mesos,
            fires: fireRisk
        )
        activePolygons = mappedPolygons

        var probabilityOverlays: [MKOverlay] = []
        var intensityOverlaysByLevel: [(level: Int, overlay: MKOverlay)] = []
        probabilityOverlays.reserveCapacity(mappedPolygons.polygons.count)

        for polygon in mappedPolygons.polygons {
            let metadata = StormRiskPolygonStyleMetadata.decode(from: polygon.subtitle)
            if let cigLevel = metadata?.cigLevel {
                let style = RiskPolygonStyleResolver.probabilityStyle(for: polygon)
                intensityOverlaysByLevel.append(
                    (
                        level: cigLevel,
                        overlay: RiskPolygonOverlay.intensity(
                        from: polygon,
                        level: cigLevel,
                        strokeColor: style.stroke,
                        fillColor: style.fill
                    )
                    )
                )
            } else {
                probabilityOverlays.append(RiskPolygonOverlay.probability(from: polygon))
            }
        }

        // Draw intensity overlays after probabilities, with higher CIG drawn last (on top):
        // bottom -> top = CIG1, CIG2, CIG3.
        let orderedIntensityOverlays = intensityOverlaysByLevel
            .sorted { $0.level < $1.level }
            .map(\.overlay)

        activeOverlays = probabilityOverlays + orderedIntensityOverlays
        selectedSevereRisks = severeRisksForSelectedLayer(for: selected)
    }
}

private struct MapLayerPickerButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.plain)
                .skyAwareSurface(
                    cornerRadius: SkyAwareRadius.section,
                    tint: .skyAwareAccent.opacity(0.18),
                    interactive: true,
                    shadowOpacity: 0.16,
                    shadowRadius: 10,
                    shadowY: 6
                )
        }
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
