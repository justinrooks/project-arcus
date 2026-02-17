//
//  ConvectiveOutlookDetailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/21/25.
//

import SwiftUI

struct ConvectiveOutlookDetailView: View {
    let outlook: ConvectiveOutlookDTO
    
    private let sectionSpacing: CGFloat = 14
    
    private var displayTitle: String {
        if let day = outlook.day {
            return "Day \(day) Convective Outlook"
        }
        return outlook.title
    }
    
    private var issuedDate: Date {
        outlook.issued ?? outlook.published
    }
    
    private var validUntilDate: Date {
        outlook.validUntil ?? outlook.published
    }
    
    private var subtitle: String? {
        guard let risk = outlook.riskLevel?.trimmingCharacters(in: .whitespacesAndNewlines), !risk.isEmpty else {
            return nil
        }
        return "Risk: \(risk.uppercased())"
    }
    
    private var fullDiscussion: String {
        if let clean = outlook.cleanText?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty {
            return clean
        }
        return outlook.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerCard
                    .padding()
                    .cardBackground(cornerRadius: 24, shadowOpacity: 0.12, shadowRadius: 16, shadowY: 8)
                
                detailSection(title: "Summary", text: outlook.summary)
                
                if !fullDiscussion.isEmpty {
                    detailSection(title: "Full Discussion", text: fullDiscussion)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("Day \(outlook.day ?? 1) Outlook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SpcProductHeader(
                title: displayTitle,
                issued: issuedDate,
                validStart: issuedDate,
                validEnd: validUntilDate,
                subtitle: subtitle,
                inZone: false,
                sender: "Storm Prediction Center"
            )
            
            Divider().opacity(0.12)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    OutlookMetaChip(title: "Published \(outlook.published.relativeDate())", icon: "clock.arrow.circlepath")
                    if let day = outlook.day {
                        OutlookMetaChip(title: "Day \(day)", icon: "calendar")
                    }
                    if let risk = outlook.riskLevel?.uppercased(), !risk.isEmpty {
                        OutlookMetaChip(title: risk, icon: "exclamationmark.triangle")
                    }
                }
                .padding(.vertical, 2)
            }
            
            SpcProductFooter(link: outlook.link, validEnd: validUntilDate)
        }
    }
    
    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(text)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .cardBackground(cornerRadius: 20, shadowOpacity: 0.10, shadowRadius: 12, shadowY: 6)
    }
}

private struct OutlookMetaChip: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .skyAwareChip(cornerRadius: 26, tint: .white.opacity(0.10), interactive: true)
    }
}

#Preview {
    NavigationStack {
        ConvectiveOutlookDetailView(outlook: ConvectiveOutlook.sampleOutlookDtos[0])
            .navigationTitle("Outlook Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
