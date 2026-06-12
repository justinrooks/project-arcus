import SwiftUI
import MapKit
import UIKit

struct MapLegend: View {
    @State private var showsHatchingExplanation = false

    let state: MapLegendState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state.layer {
            case .categorical:
                Text(state.headlineText)
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel(state.voiceOverText)
                ForEach(Array(StormRiskLevel.allCases.reversed().dropLast()), id: \.self) { level in
                    CategoricalLegendRow(risk: level)
                }

            case .meso:
                Text(state.headlineText)
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel(state.voiceOverText)
                MesoLegendRow(risk: state.layer.key.capitalized) // MESO
            
            case .fire:
                let risks = state.fireItems
                Text(state.headlineText)
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel(state.voiceOverText)
                ForEach(risks) { risk in
                    FireLegendRow(risk: risk)
                }

            case .tornado, .hail, .wind:
                let risks = state.severeItems
                Text(state.headlineText)
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel(state.voiceOverText)

                ForEach(risks) { risk in
                    SevereLegendRow(layer: state.layer, risk: risk)
                }

                if state.showsHatchingExplanation && !risks.isEmpty {
                    Divider()
                        .overlay(.secondary.opacity(0.25))
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    Button {
                        showsHatchingExplanation = true
                    } label: {
                        HatchLegendRow(hatchStyles: HatchStyle.legendPreviewStyles)
                    }
                    .buttonStyle(
                        SkyAwarePressableButtonStyle(
                            cornerRadius: SkyAwareRadius.row,
                            pressedScale: 0.99,
                            pressedOverlayOpacity: 0.06
                        )
                    )
                    .popover(isPresented: $showsHatchingExplanation, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        HatchingExplanationView()
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 144, maxWidth: 260, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .cardBackground(
            cornerRadius: SkyAwareRadius.row,
            shadowOpacity: 0.10,
            shadowRadius: 8,
            shadowY: 3
        )
    }
}

struct CompactMapLegendTrigger: View {
    let label: String
    let subtitle: String?
    let accessibilityValue: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .skyAwareSurface(
            cornerRadius: SkyAwareRadius.section,
            tint: .skyAwareAccent.opacity(0.12),
            interactive: true,
            shadowOpacity: 0.14,
            shadowRadius: 8,
            shadowY: 4
        )
        .accessibilityLabel("Map legend")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens the full map legend.")
    }
}

struct WarningLegend: View {
    let items: [WarningLegendItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Warnings")
                .font(.caption.weight(.semibold))

            ForEach(items) { item in
                WarningLegendRow(item: item)
            }
        }
        .padding(16)
        .frame(width: 160, alignment: .leading)
        .cardBackground(
            cornerRadius: SkyAwareRadius.row,
            shadowOpacity: 0.10,
            shadowRadius: 8,
            shadowY: 3
        )
    }
}

struct WarningLegendItem: Identifiable {
    private enum Kind {
        case recognized(WarningPolygonKind)
        case fallback(event: String)
    }

    private let kind: Kind
    let title: String
    let accessibilityLabel: String
    let fill: UIColor
    let stroke: UIColor

    var id: String {
        switch kind {
        case .recognized(let warningKind):
            return "recognized-\(warningKind.rawValue)"
        case .fallback(let event):
            return "fallback-\(event.lowercased())"
        }
    }

    init?(overlay: MapOverlayEntry) {
        guard overlay.key.hasPrefix("warn|"),
              let polygon = overlay.overlay as? MKPolygon,
              let rawEvent = polygon.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawEvent.isEmpty == false else {
            return nil
        }

        if let warningKind = WarningPolygonKind(event: rawEvent) {
            kind = .recognized(warningKind)
            title = warningKind.displayTitle
            accessibilityLabel = warningKind.accessibilityLabel
            let style = warningKind.style()
            fill = style.fill
            stroke = style.stroke
            return
        }

        kind = .fallback(event: rawEvent)
        title = rawEvent
        accessibilityLabel = rawEvent
        let fallbackStyle = warningPolygonStyle(for: rawEvent).map {
            (fill: $0.fill, stroke: $0.stroke)
        } ?? RiskPolygonStyleResolver.probabilityStyle(for: polygon)
        fill = fallbackStyle.fill
        stroke = fallbackStyle.stroke
    }

    static func rendered(from overlays: [MapOverlayEntry]) -> [WarningLegendItem] {
        var deduped: [WarningLegendItem] = []
        var seen = Set<String>()

        for item in overlays.compactMap(WarningLegendItem.init) {
            guard seen.insert(item.id).inserted else { continue }
            deduped.append(item)
        }

        return deduped.sorted {
            let lhsRank = $0.sortRank
            let rhsRank = $1.sortRank
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private var sortRank: Int {
        switch kind {
        case .recognized(let warningKind):
            return warningKind.rawValue
        case .fallback:
            return 3
        }
    }
}

private struct WarningLegendRow: View {
    let item: WarningLegendItem

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(item.fill))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(item.stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)

            Text(item.title)
                .font(.caption)
                .fontWeight(.regular)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }
}

private struct HatchingExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hatched Risk Areas")
                .font(.headline.weight(.semibold))

            Text("Hatching marks where stronger storms are more likely inside the broader risk area.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("When you see hatching on tornado, hail, or wind layers, SPC is signaling a higher chance of significant reports in that area.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}

// MARK: - Rows

private struct CategoricalLegendRow: View {
    let risk: StormRiskLevel

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(risk: risk.abbreviation.uppercased(), probability: "0%")
        HStack {
            LegendCircleSwatch(
                fill: fill,
                stroke: stroke,
                differentiationStyle: MapOverlayDifferentiationStyle.categorical(risk)
            )
            Text(risk.message.split(separator: " ")[0])
                .font(.caption)
                .fontWeight(["HIGH", "MDT", "ENH"].contains(risk.abbreviation.uppercased()) ? .semibold : .regular)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Severe Risk, \(risk.message)")
    }
}

private struct MesoLegendRow: View {
    let risk: String

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(risk: risk, probability: "0%")
        HStack {
            LegendCircleSwatch(
                fill: fill,
                stroke: stroke,
                differentiationStyle: .mesoscale
            )
            Text(risk)
                .font(.caption)
                .fontWeight(.regular)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mesoscale, displayed area")
    }
}

private struct SevereLegendRow: View {
    let layer: MapLayer
    let risk: SevereLegendItem

    var body: some View {
        let probability = risk.probability
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "\(layer.key) - \(probability)",
            probability: String(probability.intValue),
            spcFillHex: risk.fillHex,
            spcStrokeHex: risk.strokeHex
        )
        HStack {
            LegendCircleSwatch(
                fill: fill,
                stroke: stroke,
                differentiationStyle: MapOverlayDifferentiationStyle.severe(probability: probability)
            )
            switch probability {
            case .significant:
                Text(probability.description)
                    .font(.caption)
                    .fontWeight(.bold)
            default:
                Text(probability.description)
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(layer.accessibilityLegendTitle), \(probability.accessibilityDescription)")
    }
}

private struct FireLegendRow: View {
    let risk: FireLegendItem

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "FIRE \(risk.riskLevel)",
            probability: "0",
            spcFillHex: risk.fillHex,
            spcStrokeHex: risk.strokeHex
        )
        HStack {
            LegendCircleSwatch(
                fill: fill,
                stroke: stroke,
                differentiationStyle: MapOverlayDifferentiationStyle.fire(riskLevel: risk.riskLevel)
            )
            Text(riskLabel)
                .font(.caption)
                .fontWeight(risk.riskLevel >= 8 ? .semibold : .regular)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fire Risk, \(riskLabel)")
    }

    private var riskLabel: String {
        switch risk.riskLevel {
        case 10: return "Extreme"
        case 8: return "Critical"
        case 5: return "Elevated"
        default:
            if !risk.riskLevelDescription.isEmpty && risk.riskLevelDescription != "Unknown" {
                return risk.riskLevelDescription
            }
            return "Level \(risk.riskLevel)"
        }
    }
}

private struct HatchLegendRow: View {
    let hatchStyles: [HatchStyle]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HatchSwatchView(styles: hatchStyles)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hatching")
                    .font(.caption.weight(.semibold))

                Text("Stronger storms possible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: 128, alignment: .leading)
        .padding(.vertical, 8)
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hatching. Stronger storms possible.")
    }
}

private struct HatchSwatchView: View {
    let styles: [HatchStyle]

    var body: some View {
        let swatchShape = RoundedRectangle(cornerRadius: 6, style: .continuous)

        Canvas { context, size in
            let extent = max(size.width, size.height) * 2.0

            for style in styles {
                var layer = context
                let spacing = CGFloat(style.spacing)
                let lineWidth = CGFloat(style.lineWidth)
                let angle = Angle.degrees(style.angleDegrees)
                let dashPattern = style.dashPattern.map { CGFloat($0) }

                layer.opacity = style.opacity * 0.85
                layer.translateBy(x: size.width / 2, y: size.height / 2)
                layer.rotate(by: angle)

                var y = -extent + CGFloat(style.lineOffset)
                while y <= extent {
                    var path = Path()
                    path.move(to: CGPoint(x: -extent, y: y))
                    path.addLine(to: CGPoint(x: extent, y: y))
                    layer.stroke(
                        path,
                        with: .color(.primary.opacity(0.55)),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            dash: dashPattern,
                            dashPhase: 0
                        )
                    )
                    y += spacing
                }
            }
        }
        .drawingGroup()
        .frame(width: 24, height: 16)
        .background(.thinMaterial, in: swatchShape)
        .overlay(swatchShape.stroke(.primary.opacity(0.12), lineWidth: 1))
        .clipShape(swatchShape)
        .accessibilityHidden(true)
    }
}

private struct LegendCircleSwatch: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let fill: UIColor
    let stroke: UIColor
    let differentiationStyle: MapOverlayDifferentiationStyle?

    var body: some View {
        let strokeStyle = differentiationStyle?.strokeStyle(
            differentiateWithoutColor: differentiateWithoutColor
        )

        Circle()
            .fill(Color(fill))
            .overlay(
                Circle().stroke(
                    Color(stroke),
                    style: StrokeStyle(
                        lineWidth: 1.15 * (strokeStyle?.lineWidthMultiplier ?? 1.0),
                        dash: strokeStyle?.dashPattern ?? []
                    )
                )
            )
            .frame(width: 14, height: 14)
    }
}

// MARK: - Previews

#Preview("Categorical") {
    MapLegend(state: .loading(for: .categorical))
        .padding()
        .background(.thinMaterial)
}

#Preview("Tornado 10% + SIGN") {
    MapLegend(state: MapLegendState(
        presentationState: .current,
        layer: .tornado,
        severeItems: [
            SevereLegendItem(id: "10%", probability: .percent(0.10), fillHex: nil, strokeHex: nil),
            SevereLegendItem(id: "25% Significant", probability: .significant(25), fillHex: nil, strokeHex: nil)
        ],
        fireItems: [],
        showsHatchingExplanation: true
    ))
        .padding()
        .background(.thinMaterial)
}

#Preview("Meso") {
    MapLegend(state: .confirmedEmpty(for: .meso))
        .padding()
        .background(.thinMaterial)
}

#Preview("Warning styles") {
    WarningLegend(items: [
        .init(
            overlay: {
                let polygon = MKPolygon(
                    coordinates: [
                        CLLocationCoordinate2D(latitude: 35.0, longitude: -97.0),
                        CLLocationCoordinate2D(latitude: 35.1, longitude: -96.9),
                        CLLocationCoordinate2D(latitude: 35.2, longitude: -97.1)
                    ],
                    count: 3
                )
                polygon.title = "Tornado Warning"
                return MapOverlayEntry(
                    key: "warn|demo|rev-demo|tornado|0|demo",
                    overlay: polygon,
                    signature: 1
                )
            }()
        )!,
        .init(
            overlay: {
                let polygon = MKPolygon(
                    coordinates: [
                        CLLocationCoordinate2D(latitude: 35.2, longitude: -96.8),
                        CLLocationCoordinate2D(latitude: 35.3, longitude: -96.7),
                        CLLocationCoordinate2D(latitude: 35.4, longitude: -96.9)
                    ],
                    count: 3
                )
                polygon.title = "Flash Flood Warning"
                return MapOverlayEntry(
                    key: "warn|demo|rev-demo|flashFlood|0|demo",
                    overlay: polygon,
                    signature: 2
                )
            }()
        )!
    ])
        .padding()
        .background(.thinMaterial)
}
