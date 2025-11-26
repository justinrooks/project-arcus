//
//  WatchDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct WatchDetailView: View {
    let watch: WatchDTO
    let layout: DetailLayout
    
    // Layout metrics
    private var sectionSpacing: CGFloat { layout == .sheet ? 12 : 14 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // 🔷 Header
            let type = parseWatchType(from: watch.summary)
            SpcProductHeader(title: "\(type ?? "Watch") \(watch.number)", issued: watch.issued, validStart: watch.validStart, validEnd: watch.validEnd, subtitle: nil, inZone: false)
            
            Divider().opacity(0.12)
            
            // 🌩️ Key Threats Summary (if any)
            if let keyThreats = parseKeyThreats(from: watch.summary), !keyThreats.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expected Risks")
                        .font(.headline)
                    
                    ForEach(keyThreats, id: \.self) { threat in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: threat.icon)
                                .foregroundColor(threat.color)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(threat.color.opacity(0.2)))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(threat.title)
                                    .font(.subheadline.weight(.medium))
                                Text(threat.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous)
                        .fill(.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous))
            }
            
            SpcProductFooter(link: watch.link, validEnd: watch.validEnd)
            
            if layout == .full {
                // 📝 Full Discussion
                Divider().opacity(0.12)
                Section(header: Text("Full Discussion")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)) {
                        Text(watch.summary)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)
            }
        }
        .padding()
    }
    
    #warning("TODO: Move to a dedicated parser")
    private func parseWatchType(from text: String) -> String? {
        let pattern = #"(.+?)\s+Watch\b"#

        if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let issued = String(text[match])
            
            return issued.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
    
    #warning("TODO: Move to dedicated parser")
    private func parseKeyThreats(from text: String) -> [ThreatItem]? {
        var items: [ThreatItem] = []
        
        let threats: [(pattern: String, icon: String, title: String, color: Color)] = [
            ("tornado.*?(\\d+\\.?\\d*)", "tornado", "Tornado", Color.tornadoRed),
            ("wind.*?(\\d+[-–]\\d+|\\d+).*?mph", "wind", "Wind Gusts", Color.windTeal),
            ("hail.*?(\\d+\\.?\\d*)", "cloud.hail", "Hail Size", Color.hailBlue)
        ]
        
        for threat in threats {
            if let regex = try? NSRegularExpression(pattern: threat.pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let matchRange = Range(match.range(at: 1), in: text) {
                    let value = String(text[matchRange])
                    let detail: String
                    switch threat.title {
                    case "Tornado": detail = ""//"Estimated up to \(value) mph"
                    case "Wind Gusts": detail = "Expected range: \(value) mph"
                    case "Hail Size": detail = "Estimated size: \(value) in"
                    default: detail = value
                    }
                    items.append(ThreatItem(icon: threat.icon, title: threat.title, detail: detail, color: threat.color))
                }
            }
        }
        
        return items.isEmpty ? nil : items
    }
    
    struct ThreatItem: Hashable {
        let icon: String
        let title: String
        let detail: String
        let color: Color
    }
}

#Preview("Tornado Watch") {
    NavigationStack {
        ScrollView {
            WatchDetailView(watch: WatchModel.sampleWatcheDtos.last!, layout: .full)
                .navigationTitle("Weather Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}

#Preview("Severe Thunderstorm Watch") {
    NavigationStack {
        ScrollView {
            WatchDetailView(watch: WatchModel.sampleWatcheDtos[0], layout: .full)
                .navigationTitle("Weather Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.skyAwareBackground, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
        }
    }
}
