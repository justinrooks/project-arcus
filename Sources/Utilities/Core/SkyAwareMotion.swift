//
//  SkyAwareMotion.swift
//  SkyAware
//
//  Created by OpenAI Codex on 4/18/26.
//

import SwiftUI

enum SkyAwareMotion {
    static let resolvingBlur: CGFloat = 2.5
    static let resolvingOpacity: Double = 0.86
    static let placeholderOpacity: Double = 0.84

    static let ambientPulseDuration: Double = 3.0
    static let ambientDriftDuration: Double = 10.0

    static func resolve(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.45)
    }

    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.35)
    }

    static func message(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.30)
    }

    static func press(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.18)
    }

    static func disclosure(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.28)
    }

    static func layerChange(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.32)
    }
}
