import SwiftUI

struct MapLegend: View {
    let layer: MapLayer
    let severeRisks: [SevereRiskShapeDTO]?
    let fireRisks: [FireRiskDTO]?

    private var hasHatching: Bool {
        (severeRisks ?? []).contains { $0.intensityLevel != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch layer {
            case .categorical:
                Text("Severe Risk")
                    .font(.caption.weight(.semibold))
                ForEach(Array(StormRiskLevel.allCases.reversed().dropLast()), id: \.self) { level in
                    CategoricalLegendRow(risk: level)
                }

            case .meso:
                Text("Legend")
                    .font(.caption.weight(.semibold))
                MesoLegendRow(risk: layer.key.capitalized) // MESO
            
            case .fire:
                let risks = fireLevels
                Text(risks.isEmpty ? "No fire risk" : "Fire Risk")
                    .font(.caption.weight(.semibold))
                ForEach(risks, id: \.riskLevel) { risk in
                    FireLegendRow(risk: risk)
                }

            case .tornado, .hail, .wind:
                let risks = severeLevels
                Text(risks.isEmpty ? "No \(layer.title.lowercased()) risk" : "\(layer.title) Risk")
                    .font(.caption.weight(.semibold))

                ForEach(risks, id: \.title) { risk in
                    SevereLegendRow(layer: layer, risk: risk)
                }

                if hasHatching && !risks.isEmpty {
                    Divider()
                        .overlay(.secondary.opacity(0.25))
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    HatchLegendRow(hatchStyle: .default)
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

    private var fireLevels: [FireRiskDTO] {
        let source = fireRisks ?? []
        let mostRecentByLevel = Dictionary(
            source.map { ($0.riskLevel, $0) },
            uniquingKeysWith: { lhs, rhs in lhs.valid >= rhs.valid ? lhs : rhs }
        )
        return mostRecentByLevel.values.sorted { $0.riskLevel > $1.riskLevel }
    }

    private var severeLevels: [SevereRiskShapeDTO] {
        // CIG overlays are map texture-only for now; hide them from legend entries.
        // Also hide 0% severe rows (current feed representation for intensity-only data).
        let source = (severeRisks ?? []).filter { risk in
            if risk.intensityLevel != nil {
                return false
            }
            if case .percent(let value) = risk.probabilities, value <= 0 {
                return false
            }
            return true
        }
        let dedupedByTitle = Dictionary(
            source.map { ($0.title, $0) },
            uniquingKeysWith: { lhs, _ in lhs }
        )
        return dedupedByTitle.values.sorted {
            let lhsProbability = $0.probabilities.intValue
            let rhsProbability = $1.probabilities.intValue
            if lhsProbability != rhsProbability {
                return lhsProbability < rhsProbability
            }

            let lhsSignificanceRank = isSignificant($0.probabilities) ? 1 : 0
            let rhsSignificanceRank = isSignificant($1.probabilities) ? 1 : 0
            if lhsSignificanceRank != rhsSignificanceRank {
                return lhsSignificanceRank < rhsSignificanceRank
            }

            return $0.title < $1.title
        }
    }

    private func isSignificant(_ probability: ThreatProbability) -> Bool {
        if case .significant = probability {
            return true
        }
        return false
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
    let risk: SevereRiskShapeDTO

    var body: some View {
        let probability = risk.probabilities
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "\(layer.key) - \(probability)",
            probability: String(probability.intValue),
            spcFillHex: risk.fill,
            spcStrokeHex: risk.stroke
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
    let risk: FireRiskDTO

    var body: some View {
        let (fill, stroke) = PolygonStyleProvider.getPolygonStyleForLegend(
            risk: "FIRE \(risk.riskLevel)",
            probability: "0",
            spcFillHex: risk.fill,
            spcStrokeHex: risk.stroke
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
    let hatchStyle: HatchStyle //= HatchStyle.default

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HatchSwatchView(style: hatchStyle)

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
    let style: HatchStyle

    var body: some View {
        let swatchShape = RoundedRectangle(cornerRadius: 6, style: .continuous)

        Canvas { context, size in
            let spacing = CGFloat(style.spacing)
            let lineWidth = CGFloat(style.lineWidth)
            let angle = Angle.degrees(style.angleDegrees)

            context.opacity = style.opacity * 0.85
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: angle)

            let extent = max(size.width, size.height) * 2
            var y = -extent
            while y <= extent {
                var path = Path()
                path.move(to: CGPoint(x: -extent, y: y))
                path.addLine(to: CGPoint(x: extent, y: y))
                context.stroke(path, with: .color(.primary.opacity(0.55)), lineWidth: lineWidth)
                y += spacing
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
    MapLegend(layer: .categorical, severeRisks: nil, fireRisks: nil)
        .padding()
        .background(.thinMaterial)
}

#Preview("Tornado 10% + SIGN") {
    MapLegend(
        layer: .tornado,
        severeRisks: [
            SevereRiskShapeDTO(type: .tornado, probabilities: .percent(0.10), stroke: nil, fill: nil, polygons: []),
            SevereRiskShapeDTO(type: .tornado, probabilities: .significant(25), stroke: nil, fill: nil, polygons: [])
        ],
        fireRisks: nil
    )
        .padding()
        .background(.thinMaterial)
}

#Preview("Meso") {
    MapLegend(layer: .meso, severeRisks: nil, fireRisks: nil)
        .padding()
        .background(.thinMaterial)
}
