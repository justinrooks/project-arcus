//
//  OutlookRowView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/12/25.
//

import SwiftUI

struct OutlookRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let outlook: ConvectiveOutlookDTO
    private static let titleRegex = try? NSRegularExpression(
        pattern: #"^SPC\s+\w+\s+\d{1,2},\s+\d{4}\s+(\d{4}) UTC (.+)$"#
    )

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
//            Image(systemName: "pencil.and.list.clipboard")
//                .foregroundColor(.skyAwareAccent)
//                .font(.headline.weight(.semibold))
//                .frame(width: 40, height: 40)
//                .skyAwareChip(cornerRadius: SkyAwareRadius.iconChip, tint: Color.skyAwareAccent.opacity(0.18))

            VStack(alignment: .leading, spacing: 4) {
                titleBlock
                metadataLine
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .cardBackground(cornerRadius: SkyAwareRadius.row, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens full outlook details.")
    }

    private var titleBlock: some View {
        Text(simplifyOutlookTitle(outlook.title) ?? outlook.title)
            .font(.headline.weight(.semibold))
            .lineLimit(adaptiveLayout.usesAccessibilityLayout ? nil : 2)
            .minimumScaleFactor(adaptiveLayout.usesAccessibilityLayout ? 1 : 0.9)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metadataLine: some View {
        Group {
            if let issued = outlook.issued {
                Text("\(issued.shorten()) • \(issued.relativeDate())")
            } else {
                Text("Published \(outlook.published.relativeDate())")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.secondary)
        .lineLimit(adaptiveLayout.usesAccessibilityLayout ? 2 : 1)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityTitle: String {
        outlook.title
    }

    private var accessibilityValue: String {
        var parts: [String] = ["SPC discussion"]

        if let issued = outlook.issued {
            parts.append("Issued \(issued.shorten())")
        } else {
            parts.append("Published \(outlook.published.relativeDate())")
        }

        if let riskLevel = outlook.riskLevel?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           riskLevel.isEmpty == false {
            parts.append("Risk \(ConvectiveOutlookDetailPresentation.sentenceCaseRiskLevel(riskLevel))")
        }

        return parts.joined(separator: ". ")
    }
}

extension OutlookRowView {
    private func simplifyOutlookTitle(_ text: String) -> String? {
        guard
            let regex = Self.titleRegex,
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges == 3
        else {
            return nil
        }
        
        func group(_ i: Int) -> String {
            let r = Range(match.range(at: i), in: text)!
            return String(text[r])
        }
        
        let time = group(1)
        return "\(time)z Outlook"
    }
}

#Preview {
    OutlookRowView(outlook: ConvectiveOutlook.sampleOutlookDtos.last!)
}

#Preview("Long Title") {
    let outlook = ConvectiveOutlookDTO(
        title: "SPC Jun 15, 2026 1630 UTC Day 1 Convective Outlook With A Very Long Descriptive Title For Wrapping",
        link: URL(string: "https://www.spc.noaa.gov/products/outlook/day1otlk.html")!,
        published: Date(),
        summary: "Summary",
        fullText: "Full text",
        day: nil,
        riskLevel: "SLGT",
        issued: nil,
        validUntil: nil
    )

    return OutlookRowView(outlook: outlook)
        .padding()
        .background(Color(.skyAwareBackground))
}

#Preview("AX5") {
    OutlookRowView(outlook: ConvectiveOutlook.sampleOutlookDtos[0])
        .environment(\.dynamicTypeSize, .accessibility5)
        .padding()
        .background(Color(.skyAwareBackground))
}
