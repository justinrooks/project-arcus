//
//  OutlookView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct OutlookView: View {
    let outlook: ConvectiveOutlookDTO
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Valid time
                Text("Published: \(outlook.published, format: .dateTime)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Full text with preserved formatting
//                Text(parseOutlookText(outlook.fullText))
                Text(outlook.fullText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            }
            .padding()
        }
        .background(.cardBackground)
        .navigationTitle("Day 1 Convective Outlook")
        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button("Done") {
//                    dismiss()
//                }
//                .foregroundColor(.skyAwareAccent)
//            }
//        }
    }
    
    // Helper to parse section headers like "...SUMMARY..." and "...20z Update..."
    private func parseOutlookText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        
        // Find section headers (text between "...")
        let pattern = "\\.\\.\\.([^.]+)\\.\\.\\."
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches.reversed() { // Reverse to avoid index shifting
                if let range = Range(match.range, in: text) {
                    let start = AttributedString.Index(range.lowerBound, within: attributed)!
                    let end = AttributedString.Index(range.upperBound, within: attributed)!
                    
                    attributed[start..<end].foregroundColor = .cyan
                    attributed[start..<end].font = .body.weight(.semibold)
                }
            }
        }
        
        return attributed
    }
}

#Preview {
    let dto:ConvectiveOutlookDTO = .init(
        title: "Outlook Test",
        link: URL(string: "https://www.weather.gov/severe/outlook/test")!,
        published: Date(),
        summary: "Isolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.",
        fullText: "...SUMMARY... \nIsolated severe thunderstorms are possible through the day along the western Oregon and far northern California coastal region. Strong to locally severe gusts may accompany shallow convection that develops over parts of the Northeast.\n....20z UPDATE... \nThe only adjustment was a northward expansion of the 2% tornado and 5% wind risk probabilities across the far southwest WA coast. Recent imagery from KLGX shows a cluster of semi-discrete cells off the far southwest WA coast with weak, but discernible, mid-level rotation. Regional VWPs continue to show ample low-level shear, and surface temperatures are warming to near/slightly above the upper-end of the ensemble envelope. These kinematic/thermodynamic conditions may support at least a low-end wind and brief tornado threat along the coast.",
        day: 1,
        riskLevel: "mdt",
        issued: Date(),
        validUntil: Date()
    )
    
    return NavigationStack {
        OutlookView(outlook: dto)
    }
}
