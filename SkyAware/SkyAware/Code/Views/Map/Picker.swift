//
//  Picker.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/3/25.
//

import SwiftUI

// MARK: - Domain

enum MapLayer: String, CaseIterable, Identifiable, Sendable {
    case categorical, wind, hail, tornado, meso
    var id: String { rawValue }

    var title: String {
        switch self {
        case .categorical: return "Categorical"
        case .wind:        return "Wind"
        case .hail:        return "Hail"
        case .tornado:     return "Tornado"
        case .meso:        return "Mesoscale"
        }
    }
    
    var key: String {
        switch self {
        case .categorical: return "CAT"
        case .wind:        return "WIND"
        case .hail:        return "HAIL"
        case .tornado:     return "TOR"
        case .meso:        return "MESO"
        }
    }

    /// SF Symbols chosen to read well inside a square tile
    var symbol: String {
        switch self {
        case .categorical: return "cloud.bolt.rain.fill"// or "square.grid.2x2"   // or "chart.bar.xaxis"
        case .wind:        return "wind"
        case .hail:        return "cloud.hail.fill"
        case .tornado:     return "tornado"
        case .meso:        return "binoculars.fill"
        }
    }

    /// Simple gradient per layer; tweak colors to match your branding
    func gradient(for scheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        switch self {
        case .categorical:
            colors = scheme == .dark ? [.green.opacity(0.4), .green.darken()] : [.green.opacity(0.2), .green]
        case .wind:
            colors = scheme == .dark ? [Color.windTeal.opacity(0.6), .teal.darken()] : [Color.windTeal.opacity(0.3), .teal]
        case .hail:
            colors = scheme == .dark ? [Color.hailBlue.opacity(0.6), .blue.darken()] : [Color.hailBlue.opacity(0.3), .blue]
        case .tornado:
            colors = scheme == .dark ? [Color.tornadoRed.opacity(0.6), .red.darken()] : [Color.tornadoRed.opacity(0.5), .red]
        case .meso:
            colors = scheme == .dark ? [.indigo.opacity(0.6), .indigo.darken()] : [.indigo.opacity(0.5), .indigo]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Tile

struct LayerTile: View {
    @Environment(\.colorScheme) private var scheme
    let layer: MapLayer
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(layer.gradient(for: scheme))
                    .overlay(
                        Image(systemName: layer.symbol).formatBadgeImage()
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        // selection ring
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.2), radius: 6, y: 3)

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

    private let columns = [GridItem(.flexible()), GridItem(.flexible()),
                           GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                DismissButton()
            }
            .padding()

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(MapLayer.allCases) { layer in
                    LayerTile(layer: layer, isSelected: selection == layer) {
//                        isSelected: selection.contains(layer)
                        toggle(layer)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

            // optional helper text
            Text("Choose a layer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
        }
        .presentationDetents([.height(375)]) // looks like the Apple Maps panel
//        .presentationCornerRadius(24)
        .interactiveDismissDisabled(false)
    }

    private func toggle(_ layer: MapLayer) {
        selection = layer
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
                .font(.system(size: 35, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.secondary, .tertiary)
                .accessibilityLabel("Close")
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
    }
}

// MARK: - Example integration

struct MapWithLayerPickerDemo: View {
    @State private var showPicker = true
    @State private var selected: MapLayer = .categorical // default

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
            print("Selected layer: \(newValue.rawValue)")
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
