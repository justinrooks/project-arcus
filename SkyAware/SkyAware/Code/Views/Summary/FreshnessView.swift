//
//  FreshnessView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI

struct FreshnessView: View {
    @Environment(\.spcFreshness) private var svc: any SpcFreshnessPublishing
    @Environment(\.locationClient) private var locSvc: LocationClient

    @State private var convectiveLoad: String?
    @State private var snap: LocationSnapshot?
    
//    var lastUpdated: Date? {
//        let suite = UserDefaults(suiteName: "com.justinrooks.skyaware")
//        guard let suite else { return nil}
//        
//        let lastGlobalSuccessAtKey = "lastGlobalSuccessAt"
//        
//        let time = suite.double(forKey: lastGlobalSuccessAtKey)
//        return time > 0 ? Date(timeIntervalSince1970: time) : nil
//    }
    
    var body: some View {
        VStack {
            HStack {
                if let convectiveLoad {
                    Text("As of \(convectiveLoad)")
                }

//                if let lastFix = snap?.timestamp,
//                   (lastFix.timeIntervalSince1970 - Date().timeIntervalSince1970)  > 0 {
//                    Text("· Loc \(lastFix.shortRelativeDescription())")
//                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
//            if let last = lastUpdated {
//                Text("Updated \(relativeTime(from: last))")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            } else {
//                Text("No data yet")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
        }
        // Seed once for first paint
        .task {
            guard let lastLoad = try? await svc.latestIssue(for: .convective) else {
                convectiveLoad = "Calculating..."
                return
            }
            
            await MainActor.run { convectiveLoad = relativeTime(from: lastLoad) }
        }
        // Then react to pushes
        .task {
            let stream = await svc.convectiveIssueUpdates()
            for await d in stream {
                await MainActor.run { convectiveLoad = relativeTime(from: d) }
            }
        }
    }
    
    private func relativeTime(from date: Date) -> String {
        let now:Date = .now
        let seconds = Int(now.timeIntervalSince(date))
        if seconds <= 0 {
            return "just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        
        return "\(date.toShortTime()) (\(relative))"
    }
}

#Preview {
    let spcMock = MockSpcService(storm: .slight, severe: .tornado(probability: 0.10))
    let mdPreview = Preview(MD.self)
    mdPreview.addExamples(MD.sampleDiscussions)
    
    return FreshnessView()
        .modelContainer(mdPreview.container)
        .environment(\.spcFreshness, spcMock)
        .environment(\.locationClient, .offline)
}
