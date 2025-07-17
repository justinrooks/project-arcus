//
//  Badge.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

enum WarningLevel {
    case safe
    case warning
    case danger
    case enhanced
    case high
}

enum Threat {
    case tornado
    case wind
    case hail
    case none
}

struct Badge: View {
    let threat: Threat
    let message: String
    let summary: String
    let level: WarningLevel
    
    init(threat: Threat? = nil, message: String, summary: String, level: WarningLevel? = nil) {
        self.threat = threat ?? Threat.none
        self.message = message
        self.summary = summary
        self.level = level ?? .safe
    }
    
    var threatIcon: String {
        switch threat {
        case .tornado: return "tornado"
        case .wind: return "wind"
        case .hail: return "cloud.hail"
        case .none: return "checkmark.shield"
        }
    }
    
    var riskColor: Color {
        switch level {
        case .safe: return .green
        case .warning: return .yellow
        case .enhanced:  return .orange
        case .danger:  return .red
        case .high: return .purple
        }
    }

    var body: some View {
        //        GeometryReader { geo in
        //            let size = min(geo.size.width, geo.size.height)
        //
        VStack(spacing: 4) {
            Image(systemName: threatIcon)
                .font(.largeTitle)
                .foregroundColor(riskColor)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(summary)
                .font(.caption)
                .foregroundColor(.gray)
        }
        //            .frame(width: size, height: size)
        .frame(width: 135)
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color.black)
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4))
        //        .background(Color.black)
        //        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        //        }.aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    VStack{
        HStack{
            Badge(message: "All Clear",
                  summary: "No Severe Risk")
            Badge(threat: Threat.hail,
                  message: "Hail 1/4 inch",
                  summary: "Moderate Hail",
                  level: .warning)
        }
        HStack{
            Badge(threat: .wind,
                message: "Straighline winds",
                  summary: "Severe Risk",
                  level: .high)
            Badge(threat: Threat.tornado,
                  message: "Tornado",
                  summary: "Moderate Hail",
                  level: .danger)
        }
    }
}
