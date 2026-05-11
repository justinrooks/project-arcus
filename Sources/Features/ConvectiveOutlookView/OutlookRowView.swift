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
        Group {
            if adaptiveLayout.usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: 10) {
                    titleBlock
                    metadataLine
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundColor(.skyAwareAccent)
                        .font(.headline.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .skyAwareChip(cornerRadius: SkyAwareRadius.iconChip, tint: Color.skyAwareAccent.opacity(0.18))

                    VStack(alignment: .leading, spacing: 4) {
                        titleBlock
                        metadataLine
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(14)
        .cardBackground(cornerRadius: SkyAwareRadius.row, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1)
        .contentShape(Rectangle())
    }

    private var titleBlock: some View {
        Text(simplifyOutlookTitle(outlook.title) ?? outlook.title)
            .font(.headline.weight(.semibold))
            .lineLimit(adaptiveLayout.usesAccessibilityLayout ? 3 : 2)
            .minimumScaleFactor(adaptiveLayout.usesAccessibilityLayout ? 1 : 0.9)
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
