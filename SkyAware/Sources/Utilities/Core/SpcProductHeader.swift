//
//  SpcProductHeader.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/19/25.
//

import SwiftUI

struct SpcProductHeader: View {
    let layout: DetailLayout = .full
    let title: String
    let issued: Date
    let validStart: Date
    let validEnd: Date
    let subtitle: String
    let inZone: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: layout == .sheet ? 2 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(layout == .sheet ? .headline.weight(.semibold)
                          : .title3.weight(.semibold))
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Spacer()
                InZonePill(inZone: inZone) // The sheet view is filtered, alters and full are not
            }
            
            Text(subtitle)
                .font(.headline.weight(.semibold))
                
            Text("Issued: \(issued.shorten())")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Valid Until: \(validEnd.shorten())")
                .font(.caption)
                .foregroundStyle(.secondary)
            
//            Text("Valid: \(validStart.shorten(withDateStyle: .short)) – \(validEnd.shorten(withDateStyle: .short))")
//                .font(.caption)
//                .foregroundStyle(.secondary)
        }
//        .padding(.bottom, layout == .sheet ? 4 : 6)
    }
}

#Preview {
    SpcProductHeader(title: "Mesoscale Discussion", issued: MD.sampleDiscussionDTOs[1].issued, validStart: MD.sampleDiscussionDTOs[1].validStart, validEnd: MD.sampleDiscussionDTOs[1].validEnd, subtitle: "MD 1913", inZone: false)
}
