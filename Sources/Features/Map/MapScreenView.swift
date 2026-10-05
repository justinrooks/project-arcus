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
    @State private var reloadCoordinator = MapReloadCoordinator()

    private let primaryAwareness: SummaryAwarenessPrimaryState

    init(
        selectedLayer: Binding<MapLayer> = .constant(.categorical),
        primaryAwareness: SummaryAwarenessPrimaryState = .quiet
    ) {
        _selected = selectedLayer
        self.primaryAwareness = primaryAwareness
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
            locationCoordinate: locationSession.currentSnapshot?.coordinates,
            primaryAwareness: primaryAwareness
        )
        .onChange(of: selected, initial: true) { _, newValue in
            model.selectLayer(newValue)
        }
        .onChange(of: showsWarningGeometry, initial: true) { _, newValue in
            model.setWarningGeometryVisible(newValue)
        }
        .onChange(of: scenePhase, initial: true) { _, newValue in
            if newValue == .active {
                model.setWarningGeometryVisible(showsWarningGeometry)
            }
        }
        .onChange(of: viewportCoordinate, initial: true) { _, newValue in
            model.captureInitialCenterCoordinateIfNeeded(newValue?.coordinate)
        }
        .onDisappear {
            reloadCoordinator.cancel()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }

            let updates = await dependencies.feedStateStore.acceptedGenerationUpdates()
            scheduleReload()

            await MapFeatureModel.observeAcceptedFeedUpdates(from: updates) { _ in
                scheduleReload()
            }
        }
    }
    
    @MainActor
    private func scheduleReload() {
        reloadCoordinator.schedule {
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
    let primaryAwareness: SummaryAwarenessPrimaryState

    @State private var activeMapSheet: MapOverlaySheet?

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

            mapTopSurfaces
                .zIndex(3)

            VStack {
                Spacer()
                legendControls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(legendAllowsHitTesting)
        }
        .sheet(item: $activeMapSheet) { sheet in
            Group {
                switch sheet {
                case .legend:
                    MapLegendSheet(
                        warningItems: warningLegendItems,
                        legendState: scene.legendState
                    )
                case .awareness:
                    MapAwarenessSheet(primary: primaryAwareness)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var layerMenu: some View {
        MapLayerMenu(
            selection: $selected,
            showsWarningGeometry: $showsWarningGeometry
        )
    }

    @ViewBuilder
    private func awarenessSummary(maximumHeight: CGFloat) -> some View {
        if primaryAwareness.mapSummaryIsVisible {
            MapAwarenessDisclosure(
                primary: primaryAwareness,
                maximumHeight: maximumHeight,
                onExpand: { activeMapSheet = .awareness }
            )
            .animation(SkyAwareMotion.disclosure(reduceMotion), value: maximumHeight)
        }
    }

    private var mapTopSurfaces: some View {
        GeometryReader { geometry in
            VStack(alignment: .trailing, spacing: 12) {
                layerMenu
                    .padding(.horizontal, 14)

                awarenessSummary(maximumHeight: max(120, geometry.size.height * 0.36))
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    private var showsWarningLegend: Bool {
        warningLegendItems.isEmpty == false
    }

    private var warningLegendItems: [WarningLegendItem] {
        scene.warningLegendItems
    }

    @ViewBuilder
    private var legendControls: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 0)
            legendControlsContent
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var legendControlsContent: some View {
        switch adaptiveLayout.mapLegendMode {
        case .inline:
            ViewThatFits(in: .horizontal) {
                inlineLegendRow
                ViewThatFits(in: .vertical) {
                    stackedLegendColumn
                    compactLegendTrigger
                }
            }
        case .compactTrigger, .sheetOnly:
            compactLegendTrigger
        }
    }

    @ViewBuilder
    private var inlineLegendRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if showsWarningLegend {
                WarningLegend(items: warningLegendItems)
                    .transition(.opacity)
            }

            Spacer(minLength: 8)

            MapLegend(state: scene.legendState)
                .transition(.opacity)
                .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
        }
    }

    @ViewBuilder
    private var stackedLegendColumn: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if showsWarningLegend {
                WarningLegend(items: warningLegendItems)
                    .transition(.opacity)
            }

            MapLegend(state: scene.legendState)
                .transition(.opacity)
                .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
        }
    }

    private var compactLegendTrigger: some View {
        CompactMapLegendTrigger(
            label: compactLegendLabel,
            subtitle: compactLegendSubtitle,
            accessibilityValue: scene.legendState.voiceOverText
        ) {
            activeMapSheet = .legend
        }
        .transition(.opacity)
        .animation(SkyAwareMotion.layerChange(reduceMotion), value: selected)
    }

    private var compactLegendLabel: String {
        "Legend · \(scene.legendState.layer.title)"
    }

    private var compactLegendSubtitle: String? {
        guard showsWarningLegend else { return nil }

        let warningTitles = warningLegendItems.map(\.title)
        switch warningTitles.count {
        case 0:
            return nil
        case 1:
            return "\(warningTitles[0]) warning"
        case 2:
            return "\(warningTitles[0]) and \(warningTitles[1]) warnings"
        default:
            return "\(warningTitles.count) warning types"
        }
    }

    private var legendAllowsHitTesting: Bool {
        true
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

private enum MapOverlaySheet: String, Identifiable {
    case legend
    case awareness

    var id: Self { self }
}

private struct MapAwarenessDisclosure: View {
    let primary: SummaryAwarenessPrimaryState
    let maximumHeight: CGFloat
    let onExpand: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            MapAwarenessSummary(primary: primary)
            CompactMapAwarenessSummary(primary: primary, onExpand: onExpand)
        }
        .frame(maxHeight: maximumHeight, alignment: .top)
    }
}

private struct MapLegendSheet: View {
    @Environment(\.dismiss) private var dismiss

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct MapAwarenessSheet: View {
    @Environment(\.dismiss) private var dismiss

    let primary: SummaryAwarenessPrimaryState

    var body: some View {
        NavigationStack {
            ScrollView {
                MapAwarenessSummary(primary: primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .navigationTitle("Awareness Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct MapScreenContentPreview: View {
    let legendState: MapLegendState
    let selectedLayer: MapLayer
    let warningOverlays: [MapOverlayEntry]
    let primaryAwareness: SummaryAwarenessPrimaryState

    init(
        legendState: MapLegendState = .loading(for: .categorical),
        selectedLayer: MapLayer = .categorical,
        warningOverlays: [MapOverlayEntry] = [],
        primaryAwareness: SummaryAwarenessPrimaryState = .quiet
    ) {
        self.legendState = legendState
        self.selectedLayer = selectedLayer
        self.warningOverlays = warningOverlays
        self.primaryAwareness = primaryAwareness
    }

    var body: some View {
        MapScreenContent(
            selected: .constant(selectedLayer),
            showsWarningGeometry: .constant(true),
            scene: MapLayerScene(
                canvasState: MapCanvasState(
                    overlays: warningOverlays,
                    overlayRevision: warningOverlays.count,
                    initialCenterCoordinate: nil
                ),
                legendState: legendState,
                warningLegendItems: WarningLegendItem.rendered(from: warningOverlays)
            ),
            locationCoordinate: CLLocationCoordinate2D(latitude: 39.75, longitude: -104.44),
            primaryAwareness: primaryAwareness
        )
    }
}

private struct MapAwarenessSummary: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let primary: SummaryAwarenessPrimaryState

    var body: some View {
        cardContent
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(primary.accessibilityContract.label)
            .accessibilityValue(primary.accessibilityContract.value)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("map-awareness-summary")
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: primary.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 8) {
                    Text(primary.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                }

                if let timing = primary.mapSummaryTiming {
                    Text(timing)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(primary.mapSummaryDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 25)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(primary.accentColor)
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .accessibilityHidden(true)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
    }
}

private struct CompactMapAwarenessSummary: View {
    let primary: SummaryAwarenessPrimaryState
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: primary.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primary.accentColor)
                    .accessibilityHidden(true)

                Text(primary.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 25)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 320, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(primary.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .padding(.leading, 12)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primary.accessibilityContract.label)
        .accessibilityValue(primary.accessibilityContract.value)
        .accessibilityHint("Opens the full awareness summary.")
        .accessibilityIdentifier("map-awareness-summary-compact")
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

#Preview("Map Legend - Warning Inline Wide") {
    MapScreenContentPreview(
        legendState: MapScreenPreviewLegendState.severeWithHatching,
        selectedLayer: .tornado,
        warningOverlays: MapScreenPreviewWarningLegend.overlays
    )
    .environment(\.dynamicTypeSize, .large)
    .frame(width: 430, height: 430)
}

#Preview("Map Legend - Warning Stacked Narrow") {
    MapScreenContentPreview(
        legendState: MapScreenPreviewLegendState.severeWithHatching,
        selectedLayer: .tornado,
        warningOverlays: MapScreenPreviewWarningLegend.overlays
    )
    .environment(\.dynamicTypeSize, .large)
    .frame(width: 320, height: 568)
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
        selectedLayer: .tornado,
        warningOverlays: MapScreenPreviewWarningLegend.overlays
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map Screen - Warning Compact Trigger") {
    MapScreenContentPreview(
        legendState: MapScreenPreviewLegendState.severeWithHatching,
        selectedLayer: .tornado,
        warningOverlays: MapScreenPreviewWarningLegend.overlays
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 320, height: 568)
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
        selectedLayer: .tornado,
        warningOverlays: MapScreenPreviewWarningLegend.overlays
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Map Awareness - Active Warning Narrow") {
    MapScreenContentPreview(
        primaryAwareness: .alert(
            title: "Severe Thunderstorm Warning",
            detail: "Destructive winds and very large hail are possible across the area.",
            timing: "Until 9:00 PM MDT",
            instruction: "Seek shelter immediately."
        )
    )
    .environment(\.dynamicTypeSize, .large)
    .frame(width: 320, height: 568)
}

#Preview("Map Awareness - AX3 Active Warning Narrow") {
    MapScreenContentPreview(
        primaryAwareness: .alert(
            title: "Severe Thunderstorm Warning",
            detail: "Destructive winds and very large hail are possible across the area.",
            timing: "Until 9:00 PM MDT",
            instruction: "Seek shelter immediately."
        )
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 320, height: 568)
}

private enum MapScreenPreviewWarningLegend {
    @MainActor
    static let overlays: [MapOverlayEntry] = [
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
    ]

    @MainActor
    static let items: [WarningLegendItem] = WarningLegendItem.rendered(from: overlays)

    @MainActor
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
