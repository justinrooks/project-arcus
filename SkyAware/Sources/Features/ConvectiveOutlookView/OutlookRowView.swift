//
//  OutlookRowView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/12/25.
//

import SwiftUI

struct OutlookRowView: View {
    let outlook: ConvectiveOutlookDTO

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Type Badge
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundColor(.skyAwareAccent)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.skyAwareAccent.opacity(0.15))
                )

            if let day = simplifyOutlookTitle(outlook.title) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    
                    if let issued = outlook.issued{
                        Text("\(issued.toShortDateAndTime()) - \(issued.relativeDate())")
                            .font(.caption)
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
    func simplifyOutlookTitle(_ text: String) -> String? {
        let pattern = #"^SPC\s+\w+\s+\d{1,2},\s+\d{4}\s+(\d{4}) UTC (.+)$"#
        
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges == 3
        else {
            return nil
        }
        
        func group(_ i: Int) -> String {
            let r = Range(match.range(at: i), in: text)!
            return String(text[r])
        }
        
        let time = group(1)     // "1630"
        let rest = group(2)     // "Day 1 Convective Outlook"
        
//        return "\(time)z \(rest)"
        return "\(time)z Outlook"
    }
}

#Preview {
    OutlookRowView(outlook: ConvectiveOutlook.sampleOutlookDtos.last!)
}
