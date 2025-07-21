//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation

@MainActor
final class SpcProvider: ObservableObject {
    @Published var errorMessage: String?
    @Published var isLoading: Bool = true
    
    @Published var outlooks: [SPCConvectiveOutlook] = []
    @Published var meso: [MesoscaleDiscussion] = []
    @Published var watches: [Watch] = []
    
    private let spcClient = SpcClient()
    
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
                    .filter { $0.title?.contains("Watch") == true }
                    .compactMap { Watch.from(rssItem: $0) }
            } catch {
                self.errorMessage = error.localizedDescription
                print(self.errorMessage!)
            }
            
            self.isLoading = false
        }
    }
}
