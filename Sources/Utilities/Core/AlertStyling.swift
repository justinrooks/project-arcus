//
//  AlertStyling.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/23/26.
//

import Foundation
import SwiftUI

// TODO: There's likely a better place for this than its own file. Move it when we figure it out.
func styleForType(_ type: AlertType, _ watchType: String?) -> (String, Color) {
    switch type {
    case .watch:
        if let watchType {
            switch watchType {
            case "Tornado Watch": return ("tornado", .tornadoRed)
            case "Tornado Warning": return ("tornado", .tornadoRed)
            case "Severe Thunderstorm Watch": return ("cloud.bolt.fill", .severeTstormWarn)
            case "Severe Thunderstorm Warning": return ("cloud.bolt.fill", .severeTstormWarn)
            case "Flash Flood Warning": return ("flood.fill", .hailBlue) // TODO: Create a flood color
            default: return ("exclamationmark.triangle", .red)
            }
        } else {
            return ("exclamationmark.triangle", .red)
        }
    case .mesoscale: return ("waveform.path.ecg.magnifyingglass", .mesoPurple)
    }
}
