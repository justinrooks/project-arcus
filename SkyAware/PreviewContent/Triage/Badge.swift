//
//  Badge.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

// DEPRECATED: USE SEVERE OR RISK BADGE VIEWS
//
//enum WarningLevel: Int, Comparable {
//    case safe = 0
//    case marginal = 1
//    case slight = 2
//    case enhanced = 3
//    case moderate = 4
//    case high = 5
//    
//    static func < (lhs: WarningLevel, rhs: WarningLevel) -> Bool {
//        lhs.rawValue < rhs.rawValue
//    }
//}
//
//enum Threat: Int, Comparable {
//    case none = 0
//    case wind = 1
//    case hail = 2
//    case tornado = 3
//    
//    static func < (lhs: Threat, rhs: Threat) -> Bool {
//        lhs.rawValue < rhs.rawValue
//    }
//}
//
//struct Badge: View {
//    let threat: Threat
//    let message: String
//    let summary: String
//    let level: WarningLevel
//    
//    init(threat: Threat? = nil, message: String, summary: String, level: WarningLevel? = nil) {
//        self.threat = threat ?? Threat.none
//        self.message = message
//        self.summary = summary
//        self.level = level ?? .safe
//    }
//    
//    var threatIcon: String {
//        switch threat {
//        case .tornado: return "tornado"
//        case .wind: return "wind"
//        case .hail: return "cloud.hail"
//        case .none: return "checkmark.seal"
//        }
//    }
//    
//    var warningIcon: String {
//        switch level {
//            case .safe: return "checkmark.seal"
//            case .marginal: return "circle.dashed"
//            case .slight: return "exclamationmark.triangle.fill"
//            case .enhanced: return "bolt.fill"
//            case .moderate: return "exclamationmark.octagon"
//            case .high: return "flame"
//        }
//    }
//    
//    var gradient: LinearGradient {
//        let colors: [Color]
//        switch level {
//            case .safe: colors = [.green.opacity(0.2), .green]
//            case .marginal: colors = [Color(hue: 0.33, saturation: 0.5, brightness: 0.8), .green]
//            case .slight: colors = [Color.yellow.opacity(0.3), .yellow]
//            case .enhanced: colors = [Color.orange.opacity(0.4), .orange]
//            case .moderate: colors = [Color.red.opacity(0.5), .red]
//            case .high: colors = [.purple.opacity(0.5), .purple]
//        }
//        
//        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
//    }
//    
//    var body: some View {
//        VStack(spacing: 4) {
//            if (threat != .none) {
//                Image(systemName: threatIcon)
//                    .font(.largeTitle)
//                    .foregroundColor(.primary)
//            } else {
//                Image(systemName: warningIcon)
//                    .font(.largeTitle)
//                    .foregroundColor(.primary)
//            }
//            Text(message)
//                .font(.headline)
//                .foregroundColor(.primary)
//                .lineLimit(1)
//                .minimumScaleFactor(0.5)
//            Text(summary)
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//        .frame(minWidth: 100, idealWidth: 135, maxWidth: 135,
//               minHeight: 100, idealHeight: 135, maxHeight: 135)
//        .aspectRatio(1, contentMode: .fit)
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 16)
//                .fill(gradient)
//                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
//        )
//    }
//}
//
//#Preview {
//    VStack{
//        HStack {
//            Badge(threat: Threat.hail,
//                  message: "Hail 1/4 inch",
//                  summary: "Moderate Hail",
//                  level: .slight)
//        }
//        HStack{
//            Badge(threat: .wind,
//                  message: "Straighline winds",
//                  summary: "Severe Risk",
//                  level: .moderate)
//            Badge(threat: Threat.tornado,
//                  message: "Tornado",
//                  summary: "Moderate Hail",
//                  level: .high)
//        }
//    }
//}
