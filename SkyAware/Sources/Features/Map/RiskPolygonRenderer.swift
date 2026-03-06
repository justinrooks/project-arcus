//
//  RiskPolygonRenderer.swift
//  SkyAware
//
//  Created by Codex on 3/5/26.
//

import Foundation
import MapKit
import UIKit

final class RiskPolygonRenderer: MKOverlayPathRenderer {
    static let hatchZoomThreshold: MKZoomScale = 0.000025

    private let riskOverlay: RiskPolygonOverlay

    init(riskOverlay: RiskPolygonOverlay) {
        self.riskOverlay = riskOverlay
        super.init(overlay: riskOverlay)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func createPath() {
        path = polygonPath(for: riskOverlay.polygon)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let path else { return }

        switch riskOverlay.kind {
        case .probability:
            drawProbability(path: path, zoomScale: zoomScale, in: context)

        case .intensity(let level):
            drawIntensity(path: path, level: level, zoomScale: zoomScale, in: context)
        }
    }

    private func drawProbability(path: CGPath, zoomScale: MKZoomScale, in context: CGContext) {
        context.saveGState()

        if riskOverlay.fillColor.cgColor.alpha > 0 {
            context.addPath(path)
            context.setFillColor(riskOverlay.fillColor.cgColor)
            context.fillPath()
        }

        context.addPath(path)
        context.setStrokeColor(riskOverlay.strokeColor.cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.strokePath()

        context.restoreGState()
    }

    private func drawIntensity(path: CGPath, level: Int, zoomScale: MKZoomScale, in context: CGContext) {
        context.saveGState()

        let softFill = riskOverlay.fillColor.withAlphaComponent(min(riskOverlay.fillColor.cgColor.alpha, 0.08))
        if softFill.cgColor.alpha > 0 {
            context.addPath(path)
            context.setFillColor(softFill.cgColor)
            context.fillPath()
        }

        let outlineColor = riskOverlay.strokeColor.withAlphaComponent(0.45)
        context.addPath(path)
        context.setStrokeColor(outlineColor.cgColor)
        context.setLineWidth(0.8 / zoomScale)
        context.strokePath()

        if zoomScale >= Self.hatchZoomThreshold {
            drawHatch(path: path, level: level, zoomScale: zoomScale, in: context)
        }

        context.restoreGState()
    }

    private func drawHatch(path: CGPath, level: Int, zoomScale: MKZoomScale, in context: CGContext) {
        let style = riskOverlay.hatchStyle ?? HatchStyle.default.adjusted(forIntensityLevel: level)
        let spacing = max(8.0, style.spacing) / zoomScale
        let lineWidth = max(0.75, style.lineWidth) / zoomScale
        let hatchColor = resolvedHatchColor().withAlphaComponent(CGFloat(style.opacity))
        let angle = CGFloat(style.angleDegrees * .pi / 180)
        let lineOffset = CGFloat(style.lineOffset) / zoomScale
        let dashPattern = style.dashPattern.map { CGFloat($0) / zoomScale }

        let bounds = path.boundingBoxOfPath.insetBy(dx: -spacing, dy: -spacing)
        let diagonal = hypot(bounds.width, bounds.height)
        let halfLength = diagonal + spacing

        context.saveGState()
        context.addPath(path)
        context.clip(using: .evenOdd)

        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: angle)
        context.setStrokeColor(hatchColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        if dashPattern.isEmpty {
            context.setLineDash(phase: 0, lengths: [])
        } else {
            context.setLineDash(phase: 0, lengths: dashPattern)
        }
        context.beginPath()

        var y = -diagonal + lineOffset
        while y <= diagonal {
            context.move(to: CGPoint(x: -halfLength, y: y))
            context.addLine(to: CGPoint(x: halfLength, y: y))
            y += spacing
        }

        context.strokePath()
        context.restoreGState()
    }

    private func polygonPath(for polygon: MKPolygon) -> CGPath {
        let path = CGMutablePath()

        appendRing(points: polygon.points(), count: polygon.pointCount, into: path)

        if let interiors = polygon.interiorPolygons {
            for interior in interiors {
                appendRing(points: interior.points(), count: interior.pointCount, into: path)
            }
        }

        return path
    }

    private func appendRing(
        points: UnsafeMutablePointer<MKMapPoint>,
        count: Int,
        into path: CGMutablePath
    ) {
        guard count > 2 else { return }

        path.move(to: point(for: points[0]))
        for index in 1..<count {
            path.addLine(to: point(for: points[index]))
        }
        path.closeSubpath()
    }

    private func resolvedHatchColor() -> UIColor {
        let strokeColor = riskOverlay.strokeColor
        return UIColor { traitCollection in
            let resolvedStroke = strokeColor.resolvedColor(with: traitCollection)
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return resolvedStroke.mixed(with: .white, amount: 0.78)
            default:
                return resolvedStroke.mixed(with: .black, amount: 0.20)
            }
        }
    }
}

private extension UIColor {
    func mixed(with color: UIColor, amount: CGFloat) -> UIColor {
        let clamped = max(0, min(1, amount))

        guard let lhs = rgbaComponents, let rhs = color.rgbaComponents else {
            return self
        }

        return UIColor(
            red: lhs.red + (rhs.red - lhs.red) * clamped,
            green: lhs.green + (rhs.green - lhs.green) * clamped,
            blue: lhs.blue + (rhs.blue - lhs.blue) * clamped,
            alpha: lhs.alpha
        )
    }

    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (red, green, blue, alpha)
    }
}
