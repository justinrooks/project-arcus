//
//  Picker.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/3/25.
//

import SwiftUI
import OSLog

// MARK: - Domain

enum MapLayer: String, CaseIterable, Identifiable, Sendable {
    case categorical, wind, hail, tornado, meso, fire
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .categorical: return "Categorical"
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

// MARK: - Tile

struct LayerTile: View {
    @Environment(\.colorScheme) private var scheme
    let layer: MapLayer
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color {
        switch layer {
        case .categorical: return .riskThunderstorm.opacity(0.20)
        case .wind: return .windTeal.opacity(0.20)
        case .hail: return .hailBlue.opacity(0.20)
        case .tornado: return .tornadoRed.opacity(0.20)
        case .meso: return .mesoPurple.opacity(0.20)
        case .fire: return .fireWeather.opacity(0.20)
        }
    }

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous)
                    .fill(layer.gradient(for: scheme))
                    .overlay(
                        Image(systemName: layer.symbol).formatBadgeImage()
                    )
                    .frame(width: 74, height: 74)
                    .skyAwareSurface(
                        cornerRadius: SkyAwareRadius.medium,
                        tint: tint,
                        interactive: true,
                        shadowOpacity: scheme == .dark ? 0.20 : 0.10,
                        shadowRadius: 5,
                        shadowY: 2
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    }

                Text(layer.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(layer.title + (isSelected ? ", selected" : ""))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet

struct LayerPickerSheet: View {
    /// Use a Set for multi-select; for single-select pass allowsMultipleSelection = false
    @Binding var selection: MapLayer
    var title: String = "Map Layers"
    var triggerNamespace: Namespace.ID? = nil

    @Environment(\.dismiss) private var dismiss
    
    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 96), spacing: 14)]

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                        .skyAwareChip(cornerRadius: 10, tint: .skyAwareAccent.opacity(0.18))
                        .modifier(LayerPickerMorph(namespace: triggerNamespace))
                    Text(title)
                        .font(.title3.weight(.semibold))
                }
                Spacer(minLength: 6)
                DismissButton()
            }
            .padding()

            Text("Active: \(selection.title)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .skyAwareChip(cornerRadius: 12, tint: .white.opacity(0.09))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(MapLayer.allCases) { layer in
                        LayerTile(layer: layer, isSelected: selection == layer) {
                            toggle(layer)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 14)
            }

            Text("Choose a layer")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .presentationDetents([.height(410), .medium])
        .interactiveDismissDisabled(false)
    }

    private func toggle(_ layer: MapLayer) {
        selection = layer
        dismiss()
    }
}

// MARK: - Convenience close button (X)

private struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.headline.weight(.bold))
                .frame(width: 34, height: 34)
                .accessibilityLabel("Close")
        }
        .buttonStyle(.plain)
        .skyAwareChip(cornerRadius: 17, tint: .white.opacity(0.1), interactive: true)
        .contentShape(.rect)
    }
}

private struct LayerPickerMorph: ViewModifier {
    let namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *), let namespace {
            content.glassEffectID("map-layer-button", in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Example integration

struct MapWithLayerPickerDemo: View {
    @State private var showPicker = true
    @State private var selected: MapLayer = .categorical // default
    private let logger = Logger.uiMap

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle().fill(.ultraThinMaterial) // placeholder for your Map
                .overlay(Text("Your Map Here").font(.title3))

            Button {
                showPicker = true
            } label: {
                Label("Layers", systemImage: "slider.horizontal.3")
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .sheet(isPresented: $showPicker) {
            LayerPickerSheet(selection: $selected,
                             title: "Map Layers")
        }
        // Use `selected` to drive which overlays you render
        .onChange(of: selected) { _, newValue in
            // update overlays via your provider; debounce as needed
            logger.debug("Selected layer: \(newValue.rawValue, privacy: .public)")
        }
    }
}

// MARK: - Preview

#Preview("Layer Picker Sheet") {
    LayerPickerSheet(selection: .constant(.categorical))
}

#Preview("In-Map Demo") {
    MapWithLayerPickerDemo()
}
