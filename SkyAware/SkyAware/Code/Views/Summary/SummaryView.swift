//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

struct SummaryView: View {
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Badge(message:"All Clear", summary: "25 mi")
//                Badge(threat: .tornado, message: "Tornado", summary: "Moderate Risk", level: .danger)
//                
//                Badge(threat:.hail, message: "Hail", summary: "Up to 1/4 inch", level: .enhanced)
            }
            .padding(.horizontal)
            .fixedSize(horizontal: true, vertical: true)
            
//            VStack(alignment: .leading, spacing: 20) {
//                HStack(spacing: 8) {
//                    Image(systemName: "sun.max.fill")
//                        .foregroundColor(.yellow)
//                        .font(.title2)
//                    VStack(alignment: .leading) {
//                        Text("Today")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        Text("Mostly Sunny, high near 91°F")
//                            .font(.subheadline)
//                            .lineLimit(2)
//                    }
//                }
//                HStack(spacing: 8) {
//                    Image(systemName: "cloud.moon.fill")
//                        .foregroundColor(.blue)
//                        .font(.title2)
//                    VStack(alignment: .leading) {
//                        Text("Tonight")
//                            .font(.caption)
//                            .foregroundColor(.gray)
//                        Text("Clouds increasing, low around 62°F")
//                            .font(.subheadline)
//                            .lineLimit(2)
//                    }
//                }
//            }
//            .padding()
//            .background(Color(.systemGray6))
//            .cornerRadius(16)
            
            GroupBox{
                Text("No active mesoscale discussions near by")
            } label: {
                Label("Nearby Mesoscale Discussions", systemImage: "cloud.bolt.rain.fill")
                    .foregroundColor(.teal)
            }
            
            GroupBox{
                Text("No active watches near by")
            } label: {
                Label("Nearby Watches", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.teal)
            }
            
            GroupBox {
//                Text("Scattered severe storms with damaging winds are possible into this evening across parts of the Lower and Middle Ohio Valley. The greatest threat is in northeast Lower Michigan, where isolated hail or a tornado is possible. Further south, clusters of storms may bring damaging wind gusts through Indiana, Kentucky, and Ohio. Lesser threats exist in Oklahoma, New Mexico, and Upper Michigan.")
//                Text("Severe storms are expected this afternoon and evening across the Lower/Middle Ohio Valley, especially Indiana, Kentucky, and Ohio, with damaging wind the main threat. In northeast Lower Michigan, supercells could form with a risk of hail, damaging winds, and possibly a tornado. Scattered storms may also develop in Oklahoma, North Texas, New Mexico, and Upper Michigan, but the overall severe threat in those areas is more isolated.")
                Text("A Slight Risk is in place from northeast Lower Michigan into the Lower and Middle Ohio Valley. In Michigan, filtered heating, strong low-level flow, and modest instability (MLCAPE 1000–1500 J/kg) may allow supercells with wind, hail, and isolated tornadoes. Farther south, scattered storms from southern Illinois through Indiana and into Ohio/Kentucky may form multicell clusters with damaging winds as the main hazard. Additional isolated severe storms are possible in Oklahoma and North Texas, aided by MCVs, and over the high terrain of New Mexico and Colorado, where hail is the main concern. Activity diminishes tonight.")
            } label: {
                Label("Outlook Summary - Storm Chaser", systemImage: "sun.max.fill")
                    .foregroundStyle(.teal)
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SummaryView()
}
