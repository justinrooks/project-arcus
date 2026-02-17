//
//  OutlookRowView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/12/25.
//

import SwiftUI

struct OutlookRowView: View {
    let outlook: ConvectiveOutlookDTO
    private static let titleRegex = try? NSRegularExpression(
        pattern: #"^SPC\s+\w+\s+\d{1,2},\s+\d{4}\s+(\d{4}) UTC (.+)$"#
    )

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundColor(.skyAwareAccent)
                .font(.headline.weight(.semibold))
                .frame(width: 36, height: 36)
                .skyAwareChip(cornerRadius: 12, tint: Color.skyAwareAccent.opacity(0.18))

            if let day = simplifyOutlookTitle(outlook.title) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    
                    if let issued = outlook.issued{
                        Text("\(issued.shorten()) • \(issued.relativeDate())")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .cardRowBackground()
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
