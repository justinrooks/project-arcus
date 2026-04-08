//
//  CadenceSandboxView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI

//struct CadenceSandboxView: View {
//    @State private var risk: RiskTier = .none
//    @State private var quietHours = false
//    @State private var lowPower = false
//    @State private var mdActive = false
//    @State private var mdNearby = false
//    @State private var band: WatchProbBand = .lt20
//
//    private let planner = CadencePlanner()
//
//    var body: some View {
//        NavigationStack {
//            Form {
//                Section("Risk & Context") {
//                    Picker("Risk Tier", selection: $risk) {
//                        ForEach(RiskTier.allCases, id: \.self) { Text($0.description).tag($0) }
//                    }
//                    Toggle("Quiet Hours (23:00–06:00)", isOn: $quietHours)
//                    Toggle("Low Power Mode", isOn: $lowPower)
//                }
//                Section("Mesoscale Discussion") {
//                    Toggle("Active MD exists", isOn: $mdActive)
//                    Toggle("MD covering/nearby (≤25mi)", isOn: $mdNearby)
//                    Picker("Watch Probability", selection: $band) {
//                        ForEach(WatchProbBand.allCases, id: \.self) { Text($0.description).tag($0) }
//                    }
//                }
//
//                let state = DerivedState(
//                    riskTier: risk,
//                    md: MDContext(hasActiveMD: mdActive, watchProbBand: band, coveringOrNearby: mdNearby),
//                    quietHours: quietHours,
//                    lowPowerMode: lowPower
//                )
//                let plans = planner.plan(for: state)
//
//                Section("Computed Plans") {
//                    ForEach(plans, id: \.feed) { plan in
//                        VStack(alignment: .leading, spacing: 6) {
//                            Text(title(for: plan.feed))
//                                .font(.headline)
//                            HStack {
//                                Label("", systemImage: "timer").font(.subheadline)//Interval
//                                Text(minutes(plan.interval))
//                                Spacer()
//                                Label("", systemImage: "calendar.badge.clock").font(.subheadline) //Next
//                                Text(Relative.fromNow(plan.earliestBeginDate))
//                            }
//                            .font(.subheadline)
//                            Text(plan.reason)
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                                .textSelection(.enabled)
//                        }
//                        .padding(.vertical, 4)
//                    }
//                }
//            }
//            .navigationTitle("Cadence Sandbox")
//        }
//    }
//
//    private func title(for feed: Feed) -> String {
//        switch feed {
//        case .outlookDay1: return "Outlook (Day 1)"
//        case .meso:        return "Mesoscale Discussions"
//        }
//    }
//    private func minutes(_ t: TimeInterval) -> String {
//        let m = Int(round(t / 60))
//        return "\(m) min"
//    }
//}
//
//#Preview {
//    CadenceSandboxView()
//}
