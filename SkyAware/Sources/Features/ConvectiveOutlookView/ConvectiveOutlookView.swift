//
//  ConvectiveOutlook.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import SwiftData

struct ConvectiveOutlookView: View {
    //    @Environment(SpcProvider.self) private var provider: SpcProvider
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<ConvectiveOutlook> { $0.day == 1 },
           sort: \ConvectiveOutlook.published, order: .reverse, animation: .smooth)
    private var outlooks: [ConvectiveOutlook]
    
    var body: some View {
        Group {
            if outlooks.isEmpty {
                ContentUnavailableView("No Convective outlooks found", systemImage: "cloud.sun.fill")
            } else {
                List {
                    ForEach(outlooks) { outlook in
                        NavigationLink(destination: ConvectiveOutlookDetailView(outlook:outlook)) {
                            VStack(alignment: .leading) {
                                if let day = simplifyOutlookTitle(outlook.title) {
                                    Text("\(day)")
                                        .font(.headline)
                                        .bold()
                                } else {
                                    Text(outlook.title)
                                        .font(.title)
                                        .bold()
                                }
                                
                                Text("Published: \(formattedDate(outlook.published))")
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                        .navigationTitle("Convective Outlooks")
                        .font(.subheadline)
                    }
                    .onDelete(perform: { indexSet in
                        indexSet.forEach { index in
                            let outlook = outlooks[index]
                            modelContext.delete(outlook)
                        }
                    })
                }
                .contentMargins(.top, 0, for: .scrollContent)
                .refreshable {
                    Task {
                        //                            try await provider.fetchOutlooks()
                    }
                }
            }
        }
    }
}

extension ConvectiveOutlookView {
    // 📆 Helper for formatting the date
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
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
        
        return "\(time)z \(rest)"
    }
}

#Preview {
    let preview = Preview(ConvectiveOutlook.self)
    preview.addExamples(ConvectiveOutlook.sampleOutlooks)
    
    return NavigationStack {
        ConvectiveOutlookView()
            .modelContainer(preview.container)
            .navigationTitle("Convective Outlooks")
            .navigationBarTitleDisplayMode(.inline)
        //            .toolbarBackground(.visible, for: .navigationBar)      // <- non-translucent
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
}
