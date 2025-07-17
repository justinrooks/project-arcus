//
//  SpcProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation
import Observation
import MapKit

@MainActor
final class SpcProvider: ObservableObject {
    @Published var outlooks: [SPCConvectiveOutlook] = []
    @Published var meso: [MesoscaleDiscussion] = []
    @Published var watches: [Watch] = []
    @Published var errorMessage: String?
    @Published var pointsFile: Points?
    @Published var isLoading: Bool = true
    
    private let spcClient = SpcClient()
    
    func loadFeed() {
        isLoading = true
        
        Task {
            do {
                let result = try await spcClient.fetchFeedAndPoints()
                
                self.outlooks = result.feedData.channel!.items
                    .filter { $0.title?.contains(" Convective Outlook") == true }
                    .compactMap { SPCConvectiveOutlook.from(rssItem: $0) }
                
                self.meso = result.feedData.channel!.items
                    .filter { $0.title?.contains("SPC MD ") == true }
                    .compactMap { MesoscaleDiscussion.from(rssItem: $0) }
                
                self.watches = result.feedData.channel!.items
                    .filter { $0.title?.contains("Watch") == true }
                    .compactMap { Watch.from(rssItem: $0) }
               
                self.pointsFile = result.pointsData
                
                let bennett = CLLocationCoordinate2D(latitude: 39.75288661683443, longitude: -104.44886203922174)
                let rs = CLLocationCoordinate2D(latitude: 41.58742803813047, longitude: -109.20130027029062)
                
                let slightPolygons = self.pointsFile!.categorical.filter { $0.convectiveOutlook.lowercased() == "slgt" }
                let mrglPolygons = self.pointsFile!.categorical.filter { $0.convectiveOutlook.lowercased() == "mrgl" }
                
                let slightCoordinates: [[CLLocationCoordinate2D]] = slightPolygons.map { $0.points }
                let allSlightCoordinates: [CLLocationCoordinate2D] = slightPolygons.flatMap { $0.points }
                
                var rightOfLine = isUserRightOfLine(user: rs, path: mrglPolygons[0].points)
                var rol1 = isUserRightOfLine(user: rs, path: mrglPolygons[1].points)
                var rol2 = isUserRightOfLine(user: rs, path: mrglPolygons[2].points)
                
                var userInPoly = isUserInPolygon(user: bennett, polygonCoords: slightPolygons[0].points)
                print(userInPoly)
            } catch {
                self.errorMessage = error.localizedDescription
            }
            
            self.isLoading = false
        }
    }
}
