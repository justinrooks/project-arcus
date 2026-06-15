//
//  Picker.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/3/25.
//

import SwiftUI

// MARK: - Domain

enum MapLayer: String, CaseIterable, Identifiable, Sendable {
    case categorical, wind, hail, tornado, meso, fire
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .categorical: return "Severe Risk"
        case .wind:        return "Wind"
        case .hail:        return "Hail"
        case .tornado:     return "Tornado"
        case .meso:        return "Mesoscale"
        case .fire:        return "Fire"
        }
    }
    
    var key: String {
        switch self {
        case .categorical: return "CAT"
        case .wind:        return "WIND"
        case .hail:        return "HAIL"
        case .tornado:     return "TOR"
        case .meso:        return "MESO"
        case .fire:        return "FIRE"
        }
    }
    
    /// SF Symbols chosen to read well inside a square tile
    var symbol: String {
        switch self {
        case .categorical: return "cloud.bolt.rain.fill"// or "square.grid.2x2"   // or "chart.bar.xaxis"
        case .wind:        return "wind"
        case .hail:        return "cloud.hail.fill"
        case .tornado:     return "tornado"
        case .meso:        return "waveform.path.ecg.magnifyingglass"
        case .fire:        return "flame.fill"
        }
    }
    
    /// Simple gradient per layer; tweak colors to match your branding
    func gradient(for scheme: ColorScheme) -> LinearGradient {
        switch self {
        case .categorical: return Color.riskThunderstorm.tileGradient(for: scheme)
        case .wind: return Color.windTeal.tileGradient(for: scheme)
        case .hail: return Color.hailBlue.tileGradient(for: scheme)
        case .tornado: return Color.tornadoRed.tileGradient(for: scheme)
        case .meso: return Color.mesoPurple.tileGradient(for: scheme)
        case .fire: return Color.fireWeather.tileGradient(for: scheme)
        }
    }
}

struct MapLayerMenuAccessibilityState: Equatable, Sendable {
    let label: String
    let isSelected: Bool
}

// MARK: - Menu

struct MapLayerMenu: View {
    @Binding var selection: MapLayer
    @Binding var showsWarningGeometry: Bool

    var body: some View {
        Menu {
            Picker("Map layer", selection: $selection) {
                ForEach(MapLayer.allCases) { layer in
                    let accessibilityState = Self.accessibilityState(for: layer, selection: selection)

                    Label(layer.title, systemImage: layer.symbol)
                        .tag(layer)
                        .accessibilityLabel(accessibilityState.label)
                        .accessibilityAddTraits(accessibilityState.isSelected ? .isSelected : [])
                }
            }

            Divider()

            Toggle("Show Active Alerts", isOn: $showsWarningGeometry)
        } label: {
            MapLayerMenuLabel(layer: selection)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .accessibilityLabel("Map layers")
        .accessibilityValue(selection.title)
        .accessibilityHint("Opens a menu to choose the map layer or toggle active alerts.")
        .modifier(MapLayerPickerButtonStyle())
        .sensoryFeedback(.selection, trigger: selection)
    }

    static func shouldUpdateSelection(current: MapLayer, to candidate: MapLayer) -> Bool {
        current != candidate
    }

    static func showsWarningGeometryTogglePolicy(dynamicTypeSize _: DynamicTypeSize) -> Bool {
        true
    }

    static func accessibilityState(for layer: MapLayer, selection: MapLayer) -> MapLayerMenuAccessibilityState {
        MapLayerMenuAccessibilityState(label: layer.title, isSelected: layer == selection)
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

private struct MapLayerMenuLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let layer: MapLayer

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        labelBody(title: layer.title)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Capsule())
    }

    @ViewBuilder
    private func labelBody(title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: layer.symbol)
                .imageScale(.medium)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(title)
                .font(adaptiveLayout.usesAccessibilityLayout ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(adaptiveLayout.usesAccessibilityLayout ? 2 : 1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 12)
        }
    }
}

// MARK: - Preview

#Preview("Map Layer Menu - Normal") {
    MapLayerMenu(selection: .constant(.categorical), showsWarningGeometry: .constant(true))
}

#Preview("Map Layer Menu - AX3") {
    MapLayerMenu(selection: .constant(.categorical), showsWarningGeometry: .constant(true))
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Map Layer Menu - Dark") {
    MapLayerMenu(selection: .constant(.tornado), showsWarningGeometry: .constant(true))
        .environment(\.colorScheme, .dark)
}

#Preview("Map Layer Menu - AX3 Small iPhone") {
    MapLayerMenu(selection: .constant(.categorical), showsWarningGeometry: .constant(true))
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 320, height: 568)
}
