import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import SkyAware

@Suite("Onboarding secondary action contrast")
@MainActor
struct OnboardingSecondaryActionStyleTests {
    @Test("dark appearance keeps enabled text readable at rest and while pressed")
    func darkAppearanceContrast() throws {
        let pixels = try RGBAImage(image: render(colorScheme: .dark))
        let background = pixels.pixel(x: 0, y: 0)
        let foreground = try pixels.mostContrastingPixel(against: background)

        #expect(contrastRatio(foreground, background) >= 4.5)
        #expect(contrastRatio(foreground.blended(over: background, alpha: 0.7), background) >= 4.5)
    }

    @Test("Increase Contrast retains readable semantic foreground in dark appearance")
    func increasedContrastRemainsReadable() throws {
        let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { traits in
            traits.accessibilityContrast = .high
        }
        guard
            let canvasColor = UIColor(named: "skyAwareBackground"),
            let foreground = rgba(UIColor.label.resolvedColor(with: traits)),
            let background = rgba(canvasColor.resolvedColor(with: traits))
        else {
            throw RenderError.colorsUnavailable
        }

        #expect(contrastRatio(foreground, background) >= 4.5)
        #expect(contrastRatio(foreground.blended(over: background, alpha: 0.7), background) >= 4.5)
    }

    @Test("light appearance retains the established accent foreground")
    func lightAppearanceRetainsAccent() throws {
        let pixels = try RGBAImage(image: render(colorScheme: .light))
        let background = pixels.pixel(x: 0, y: 0)
        let foreground = try pixels.mostContrastingPixel(against: background)
        guard
            let accent = UIColor(named: "SkyAwareAccent")?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)),
            let components = accent.cgColor.components,
            components.count >= 3
        else {
            throw RenderError.accentUnavailable
        }
        let accentComponents = RGBA(red: components[0], green: components[1], blue: components[2])

        #expect(distance(foreground, accentComponents) < 0.08)
    }

    private func render(colorScheme: ColorScheme) throws -> CGImage {
        let view = Button("Skip for Now", action: {})
            .buttonStyle(OnboardingSecondaryActionStyle())
            .frame(width: 240, height: 56)
            .background(Color(.skyAwareBackground))
            .environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.cgImage else { throw RenderError.imageUnavailable }
        return image
    }

    private func contrastRatio(_ first: RGBA, _ second: RGBA) -> Double {
        let luminances = [first.luminance, second.luminance].sorted(by: >)
        return (luminances[0] + 0.05) / (luminances[1] + 0.05)
    }

    private func distance(_ first: RGBA, _ second: RGBA) -> Double {
        sqrt(pow(first.red - second.red, 2) + pow(first.green - second.green, 2) + pow(first.blue - second.blue, 2))
    }

    private func rgba(_ color: UIColor) -> RGBA? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return nil }
        return RGBA(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

private struct RGBAImage {
    private let width: Int
    private let height: Int
    private let bytes: [UInt8]

    init(image: CGImage) throws {
        let imageWidth = image.width
        let imageHeight = image.height
        var storage = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)
        let rendered = storage.withUnsafeMutableBytes { buffer in
            guard
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: imageWidth,
                    height: imageHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: imageWidth * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                )
            else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            return true
        }
        guard rendered else { throw RenderError.contextUnavailable }
        width = imageWidth
        height = imageHeight
        bytes = storage
    }

    func pixel(x: Int, y: Int) -> RGBA {
        let offset = (y * width + x) * 4
        return RGBA(
            red: Double(bytes[offset]) / 255,
            green: Double(bytes[offset + 1]) / 255,
            blue: Double(bytes[offset + 2]) / 255
        )
    }

    func mostContrastingPixel(against background: RGBA) throws -> RGBA {
        var best: RGBA?
        var bestDistance = 0.0
        for y in 0..<height {
            for x in 0..<width {
                let candidate = pixel(x: x, y: y)
                let candidateDistance = sqrt(
                    pow(candidate.red - background.red, 2)
                        + pow(candidate.green - background.green, 2)
                        + pow(candidate.blue - background.blue, 2)
                )
                if candidateDistance > bestDistance {
                    best = candidate
                    bestDistance = candidateDistance
                }
            }
        }
        guard let best, bestDistance > 0.1 else { throw RenderError.foregroundUnavailable }
        return best
    }
}

private struct RGBA {
    let red: Double
    let green: Double
    let blue: Double

    var luminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func blended(over background: RGBA, alpha: Double) -> RGBA {
        RGBA(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha)
        )
    }
}

private enum RenderError: Error {
    case imageUnavailable
    case contextUnavailable
    case foregroundUnavailable
    case accentUnavailable
    case colorsUnavailable
}
