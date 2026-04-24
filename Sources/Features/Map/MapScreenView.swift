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
        .onAppear {
            model.setWarningGeometryVisible(showsWarningGeometry)
            Task {
                await model.reload(
                    using: dependencies.spcMapData,
                    warningSource: dependencies.arcusProvider,
                    selectedLayer: selected
                )
            }
        }
        .onChange(of: selected, initial: true) { _, newValue in
            model.selectLayer(newValue)
        }
        .onChange(of: showsWarningGeometry, initial: true) { _, newValue in
            model.setWarningGeometryVisible(newValue)
        }
        .onChange(of: scenePhase, initial: true) { _, newValue in
            guard newValue == .active else { return }
            model.setWarningGeometryVisible(showsWarningGeometry)
            Task {
                await model.reload(
                    using: dependencies.spcMapData,
                    warningSource: dependencies.arcusProvider,
                    selectedLayer: selected
                )
            }
        }
        .onChange(of: viewportCoordinate, initial: true) { _, newValue in
            model.captureInitialCenterCoordinateIfNeeded(newValue?.coordinate)
        }
        .onDisappear {
            model.cancelWork()
        }
    }
}

private struct MapScreenContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selected: MapLayer
    @Binding var showLayerPicker: Bool
    @Binding var showsWarningGeometry: Bool

    let scene: MapLayerScene
    let layerNamespace: Namespace.ID

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
                MapLegend(state: scene.legendState)
                    .transition(.opacity)
                    .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
                    .padding([.bottom, .trailing])
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .allowsHitTesting(scene.legendState.allowsInteraction)
        }
        .sheet(isPresented: $showLayerPicker) {
            LayerPickerSheet(
                selection: $selected,
                showsWarningGeometry: $showsWarningGeometry,
                title: "Map Layers",
                triggerNamespace: layerNamespace
            )
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

#Preview {
    MapScreenContentPreview()
}

private struct MapScreenContentPreview: View {
    @Namespace private var layerNamespace

    var body: some View {
        MapScreenContent(
            selected: .constant(.categorical),
            showLayerPicker: .constant(false),
            showsWarningGeometry: .constant(true),
            scene: MapLayerScene.placeholder(for: .categorical),
            layerNamespace: layerNamespace
        )
    }
}
