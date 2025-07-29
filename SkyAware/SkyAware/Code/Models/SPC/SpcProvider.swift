//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation

@MainActor
@Observable
final class SpcProvider: ObservableObject {
    var errorMessage: String?
    var isLoading: Bool = true
    
    var outlooks: [SPCConvectiveOutlook] = []
    var meso: [MesoscaleDiscussion] = []
    var watches: [Watch] = []
    var alertCount: Int = 0
    
    @ObservationIgnored private let spcClient = SpcClient()
    
    init() {
        loadFeed()
    }
    
    func loadFeed() {
        isLoading = true
        
        Task {
            do {
                let result = try await spcClient.fetchRss()
                
                self.outlooks = result.channel!.items
                    .filter { $0.title?.contains(" Convective Outlook") == true }
                    .compactMap { SPCConvectiveOutlook.from(rssItem: $0) }
                
                self.meso = result.channel!.items
                    .filter { $0.title?.contains("SPC MD ") == true }
                    .compactMap { MesoscaleDiscussion.from(rssItem: $0) }
                
                self.watches = result.channel!.items
                    .filter { $0.title?.contains("Watch") == true && $0.title?.contains("Status Reports") == false }
                    .compactMap { Watch.from(rssItem: $0) }
                
                self.alertCount = self.meso.count + self.watches.count
            } catch {
                self.errorMessage = error.localizedDescription
                print(self.errorMessage!)
            }
            
            self.isLoading = false
        }
    }
}
