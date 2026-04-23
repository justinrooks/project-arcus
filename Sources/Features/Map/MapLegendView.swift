import SwiftUI

struct MapLegend: View {
    @State private var showsHatchingExplanation = false

    let state: MapLegendState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state.layer {
            case .categorical:
                Text("Severe Risk")
                    .font(.caption.weight(.semibold))
                ForEach(Array(StormRiskLevel.allCases.reversed().dropLast()), id: \.self) { level in
                    CategoricalLegendRow(risk: level)
                }

            case .meso:
                Text("Legend")
                    .font(.caption.weight(.semibold))
                MesoLegendRow(risk: state.layer.key.capitalized) // MESO
            
            case .fire:
                let risks = state.fireItems
                Text(risks.isEmpty ? "No fire risk" : "Fire Risk")
                    .font(.caption.weight(.semibold))
                ForEach(risks) { risk in
                    FireLegendRow(risk: risk)
                }

            case .tornado, .hail, .wind:
                let risks = state.severeItems
                Text(risks.isEmpty ? "No \(state.layer.title.lowercased()) risk" : "\(state.layer.title) Risk")
                    .font(.caption.weight(.semibold))

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
        .frame(minWidth: 144, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .cardBackground(
            cornerRadius: SkyAwareRadius.row,
            shadowOpacity: 0.10,
            shadowRadius: 8,
            shadowY: 3
        )
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
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
            Text(risk.message.split(separator: " ")[0])
                .font(.caption)
                .fontWeight(["HIGH", "MDT", "ENH"].contains(risk.abbreviation.uppercased()) ? .semibold : .regular)
        }
    }
}

private struct MesoLegendRow: View {
    let risk: String

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(risk: risk, probability: "0%")
        HStack {
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
            Text(risk)
                .font(.caption)
                .fontWeight(.regular)
        }
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
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
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
            Circle()
                .fill(Color(fill))
                .overlay(
                    Circle().stroke(Color(stroke), lineWidth: 1.15)
                )
                .frame(width: 14, height: 14)
            Text(riskLabel)
                .font(.caption)
                .fontWeight(risk.riskLevel >= 8 ? .semibold : .regular)
        }
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
        HStack(alignment: .center, spacing: 8) {
            HatchSwatchView(styles: hatchStyles)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hatching")
                    .font(.caption.weight(.semibold))

                Text("Stronger storms possible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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

// MARK: - Previews

#Preview("Categorical") {
    MapLegend(state: .empty(for: .categorical))
        .padding()
        .background(.thinMaterial)
}

#Preview("Tornado 10% + SIGN") {
    MapLegend(state: MapLegendState(
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
    MapLegend(state: .empty(for: .meso))
        .padding()
        .background(.thinMaterial)
}
