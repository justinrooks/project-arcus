//
//  MapScreenView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/18/25.
//

import SwiftUI
import CoreLocation
import MapKit

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
            showsWarningGeometry: $showsWarningGeometry,
            scene: model.activeScene,
            locationCoordinate: locationSession.currentSnapshot?.coordinates
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
    @Binding var showsWarningGeometry: Bool

    let scene: MapLayerScene
    let locationCoordinate: CLLocationCoordinate2D?

    @State private var showsLegendSheet = false

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private var accessibilitySummary: MapAccessibilitySummary {
        MapAccessibilitySummary.make(
            scene: scene,
            locationCoordinate: locationCoordinate,
            showsWarningGeometry: showsWarningGeometry
        )
    }

    var body: some View {
        ZStack {
            MapCanvasView(state: scene.canvasState)
                .ignoresSafeArea()

            MapAccessibilitySummaryElement(summary: accessibilitySummary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 8)
                .padding(.leading, 8)
                .zIndex(1)

            VStack(alignment: .trailing) {
                MapLayerMenu(
                    selection: $selected,
                    showsWarningGeometry: $showsWarningGeometry
                )
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
                        WarningLegend(items: warningLegendItems)
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
        .sheet(isPresented: $showsLegendSheet) {
            MapLegendSheet(
                warningItems: warningLegendItems,
                legendState: scene.legendState
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var showsWarningLegend: Bool {
        warningLegendItems.isEmpty == false
    }

    private var warningLegendItems: [WarningLegendItem] {
        WarningLegendItem.rendered(from: scene.canvasState.overlays)
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

private struct MapLegendSheet: View {
    let warningItems: [WarningLegendItem]
    let legendState: MapLegendState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if warningItems.isEmpty == false {
                        WarningLegend(items: warningItems)
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
            showsWarningGeometry: .constant(true),
            scene: MapLayerScene(
                canvasState: MapCanvasState(overlays: [], overlayRevision: 0, initialCenterCoordinate: nil),
                legendState: legendState
            ),
            locationCoordinate: CLLocationCoordinate2D(latitude: 39.75, longitude: -104.44)
        )
    }
}

private struct MapAccessibilitySummaryElement: View {
    let summary: MapAccessibilitySummary

    var body: some View {
        Text(summary.value)
            .font(.caption2)
            .foregroundStyle(.clear)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 260, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary.label)
            .accessibilityValue(summary.value)
            .accessibilityHint("Summarizes the selected layer, map status, local relationship, and active warnings overlay.")
            .allowsHitTesting(false)
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
        warningItems: MapScreenPreviewWarningLegend.items,
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

#Preview("Map Screen - AX5 Summary") {
    MapScreenContentPreview(
        legendState: MapScreenPreviewLegendState.severeWithHatching,
        selectedLayer: .tornado
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

private enum MapScreenPreviewWarningLegend {
    static let items: [WarningLegendItem] = WarningLegendItem.rendered(from: [
        MapOverlayEntry(
            key: "warn|demo|rev-demo|tornado|0|demo",
            overlay: previewPolygon(title: "Tornado Warning"),
            signature: 1
        ),
        MapOverlayEntry(
            key: "warn|demo|rev-demo|flashFlood|0|demo",
            overlay: previewPolygon(title: "Flash Flood Warning"),
            signature: 2
        )
    ])

    private static func previewPolygon(title: String) -> MKPolygon {
        let polygon = MKPolygon(
            coordinates: [
                CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
                CLLocationCoordinate2D(latitude: 35.1, longitude: -96.9),
                CLLocationCoordinate2D(latitude: 35.2, longitude: -97.1)
            ],
            count: 3
        )
        polygon.title = title
        return polygon
    }
}
