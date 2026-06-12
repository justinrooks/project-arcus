//
//  MapScreenView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import CoreLocation

struct MapScreenView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies
    @Environment(LocationSession.self) private var locationSession
    @AppStorage(
        "mapWarningGeometryVisible",
        store: UserDefaults.shared
    ) private var showsWarningGeometry: Bool = true

    @Binding private var selected: MapLayer
    @State private var model = MapFeatureModel()
    @State private var reloadTask: Task<Void, Never>?
    @State private var showLayerPicker = false
    @Namespace private var layerNamespace

    init(selectedLayer: Binding<MapLayer> = .constant(.categorical)) {
        _selected = selectedLayer
    }

    private var viewportCoordinate: ViewportCoordinate? {
        guard let coordinates = locationSession.currentSnapshot?.coordinates else { return nil }
        return ViewportCoordinate(coordinates)
    }

    var body: some View {
        MapScreenContent(
            selected: $selected,
            showLayerPicker: $showLayerPicker,
            showsWarningGeometry: $showsWarningGeometry,
            scene: model.activeScene,
            layerNamespace: layerNamespace
        )
        .onChange(of: selected, initial: true) { _, newValue in
            model.selectLayer(newValue)
        }
        .onChange(of: showsWarningGeometry, initial: true) { _, newValue in
            model.setWarningGeometryVisible(newValue)
        }
        .onChange(of: scenePhase, initial: true) { _, newValue in
            guard newValue == .active else { return }
            model.setWarningGeometryVisible(showsWarningGeometry)
            scheduleReload()
        }
        .onChange(of: viewportCoordinate, initial: true) { _, newValue in
            model.captureInitialCenterCoordinateIfNeeded(newValue?.coordinate)
        }
        .onDisappear {
            reloadTask?.cancel()
            reloadTask = nil
            model.cancelWork()
        }
    }
    
    @MainActor
        private func scheduleReload() {
            reloadTask?.cancel()
            reloadTask = Task {
                await model.reload(
                    using: dependencies.spcMapData,
                    warningSource: dependencies.arcusProvider,
                    selectedLayer: selected
                )
            }
        }
}

private struct MapScreenContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selected: MapLayer
    @Binding var showLayerPicker: Bool
    @Binding var showsWarningGeometry: Bool

    let scene: MapLayerScene
    let layerNamespace: Namespace.ID

    @State private var showsLegendSheet = false

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        ZStack {
            MapCanvasView(state: scene.canvasState)
                .ignoresSafeArea()

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
                                .contentTransition(.opacity)
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
                    .animation(SkyAwareMotion.press(reduceMotion), value: showLayerPicker)
                    .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
                    .modifier(MapLayerPickerButtonStyle())
                    .modifier(MapLayerButtonMorph(namespace: layerNamespace))
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(3)

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    if showsWarningLegend && adaptiveLayout.mapLegendMode == .inline {
                        WarningLegend()
                            .transition(.opacity)
                    }

                    Spacer(minLength: 8)

                    mapLegendControl
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(legendAllowsHitTesting)
        }
        .sheet(isPresented: $showLayerPicker) {
            LayerPickerSheet(
                selection: $selected,
                showsWarningGeometry: $showsWarningGeometry,
                title: "Map Layers",
                triggerNamespace: layerNamespace
            )
        }
        .sheet(isPresented: $showsLegendSheet) {
            MapLegendSheet(showWarnings: showsWarningLegend, legendState: scene.legendState)
            .presentationDetents([.medium, .large])
        }
    }

    private var showsWarningLegend: Bool {
        scene.canvasState.overlays.contains { $0.key.hasPrefix("warn|") }
    }

    @ViewBuilder
    private var mapLegendControl: some View {
        switch adaptiveLayout.mapLegendMode {
        case .inline:
            MapLegend(state: scene.legendState)
                .transition(.opacity)
                .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
        case .compactTrigger, .sheetOnly:
            CompactMapLegendTrigger(
                label: compactLegendLabel,
                accessibilityValue: scene.legendState.voiceOverText
            ) {
                showsLegendSheet = true
            }
            .transition(.opacity)
            .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
        }
    }

    private var compactLegendLabel: String {
        "Legend · \(scene.legendState.layer.title)"
    }

    private var legendAllowsHitTesting: Bool {
        switch adaptiveLayout.mapLegendMode {
        case .inline:
            return scene.legendState.allowsInteraction
        case .compactTrigger, .sheetOnly:
            return true
        }
    }
}

private struct ViewportCoordinate: Equatable {
    let coordinate: CLLocationCoordinate2D

    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    static func == (lhs: ViewportCoordinate, rhs: ViewportCoordinate) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
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

private struct MapLegendSheet: View {
    let showWarnings: Bool
    let legendState: MapLegendState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if showWarnings {
                        WarningLegend()
                            .fixedSize(horizontal: false, vertical: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    MapLegend(state: legendState)
                        .fixedSize(horizontal: false, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .navigationTitle("Legend")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MapScreenContentPreview: View {
    @Namespace private var layerNamespace

    let legendState: MapLegendState
    let selectedLayer: MapLayer

    init(
        legendState: MapLegendState = .loading(for: .categorical),
        selectedLayer: MapLayer = .categorical
    ) {
        self.legendState = legendState
        self.selectedLayer = selectedLayer
    }

    var body: some View {
        MapScreenContent(
            selected: .constant(selectedLayer),
            showLayerPicker: .constant(false),
            showsWarningGeometry: .constant(true),
            scene: MapLayerScene(
                canvasState: MapCanvasState(overlays: [], overlayRevision: 0, initialCenterCoordinate: nil),
                legendState: legendState
            ),
            layerNamespace: layerNamespace
        )
    }
}

private enum MapScreenPreviewLegendState {
    static let severeWithHatching = MapLegendState(
        presentationState: .current,
        layer: .tornado,
        severeItems: [
            SevereLegendItem(id: "5%", probability: .percent(0.05), fillHex: nil, strokeHex: nil),
            SevereLegendItem(id: "10%", probability: .percent(0.10), fillHex: nil, strokeHex: nil),
            SevereLegendItem(id: "15%", probability: .percent(0.15), fillHex: nil, strokeHex: nil),
            SevereLegendItem(id: "Sig 10%", probability: .significant(10), fillHex: nil, strokeHex: nil)
        ],
        fireItems: [],
        showsHatchingExplanation: true
    )

    static let severeWithoutHatching = MapLegendState(
        presentationState: .current,
        layer: .tornado,
        severeItems: [
            SevereLegendItem(id: "5%", probability: .percent(0.05), fillHex: nil, strokeHex: nil),
            SevereLegendItem(id: "10%", probability: .percent(0.10), fillHex: nil, strokeHex: nil)
        ],
        fireItems: [],
        showsHatchingExplanation: false
    )
}

#Preview("Map Legend - Normal Inline") {
    MapScreenContentPreview()
        .environment(\.dynamicTypeSize, .large)
}

#Preview("Map Legend - XXXL Inline") {
    MapScreenContentPreview()
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Map Legend - AX1 Compact Trigger") {
    MapScreenContentPreview(
        legendState: MapScreenPreviewLegendState.severeWithHatching,
        selectedLayer: .tornado
    )
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Map Legend - AX3 Compact Trigger") {
    MapScreenContentPreview(
        legendState: MapScreenPreviewLegendState.severeWithHatching,
        selectedLayer: .tornado
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map Legend Sheet - AX3 Small iPhone") {
    MapLegendSheet(
        showWarnings: true,
        legendState: MapScreenPreviewLegendState.severeWithHatching
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 320, height: 568)
}

#Preview("Map Legend - No Hatching Rows") {
    MapLegend(state: MapScreenPreviewLegendState.severeWithoutHatching)
        .padding()
        .background(.thinMaterial)
}
