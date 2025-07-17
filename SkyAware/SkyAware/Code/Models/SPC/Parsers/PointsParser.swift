//
//  PointsParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/14/25.
//

import Foundation
import CoreLocation

enum SevereRiskType: String {
    case tornado, hail, wind
}
enum PointsSection: String {
    case tornado, hail, wind, categorical
}

enum ConvectiveRisk: String {
    case tstm, mrgl, slgt, enh, mdt, high
}

// MARK: - Model Definitions
struct Points: Identifiable {
    let id: UUID = UUID()
    let valid: String
    let issued: String
    let severe: [SeverePolygon]
    let categorical: [OutlookPolygon]
}

struct SeverePolygon: Identifiable {
    let id: UUID = UUID()
    let type: SevereRiskType
    let points: [SeverePoint]
}

struct SeverePoint: Identifiable {
    let id: UUID = UUID()
    let probability: Double
    let points: [CLLocationCoordinate2D]
}

struct OutlookPolygon: Identifiable {
    let id: UUID = UUID()
    let convectiveOutlook: String
    let points: [CLLocationCoordinate2D]
}

struct PointsFileParser {
    // MARK: - File Parser
    func parse(content: String) -> Points {
        var issued = ""
        var valid = ""
        var severePolygons: [SeverePolygon] = []
        var outlookPolygons: [OutlookPolygon] = []
        
        var severePoints: [SeverePoint] = []
        
        let lines = content.components(separatedBy: .newlines)
        
        var section: PointsSection? = nil
        
        // MARK: Holders for Categorical
        var currentRiskCategory: String? = nil
        var currentPoints: [CLLocationCoordinate2D] = []
        
        // MARK: Holders for Severe
        var currentProbability: Double? = nil
        var tornPoints: [SeverePoint] = []
        var hailPoints: [SeverePoint] = []
        var windPoints: [SeverePoint] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.uppercased().contains("CDT"), issued.isEmpty {
                issued = trimmed
                continue
            }
            
            if trimmed.uppercased().hasPrefix("VALID TIME") {
                valid = trimmed.replacingOccurrences(of: "VALID TIME ", with: "")
                continue
            }
            
            if trimmed.uppercased().contains("TORNADO") {
                section = .tornado
                continue
            }
            else if trimmed.uppercased().contains("HAIL") {
                section = .hail
                continue
            }
            else if trimmed.uppercased().contains("WIND") {
                section = .wind
                continue
            }
            else if trimmed.uppercased().contains("CATEGORICAL OUTLOOK POINTS DAY 1") {
                section = .categorical
                continue
            }
            
            switch section {
            case .tornado:
                handleSevereSectionLine(type: .tornado, line: trimmed, currentProbability: &currentProbability, currentPoints: &currentPoints, severePoints: &severePoints, tornPoints: &tornPoints, hailPoints: &hailPoints, windPoints: &windPoints)
            case .hail:
                handleSevereSectionLine(type: .hail, line: trimmed, currentProbability: &currentProbability, currentPoints: &currentPoints, severePoints: &severePoints, tornPoints: &tornPoints, hailPoints: &hailPoints, windPoints: &windPoints)
            case .wind:
                handleSevereSectionLine(type: .wind, line: trimmed, currentProbability: &currentProbability, currentPoints: &currentPoints, severePoints: &severePoints, tornPoints: &tornPoints, hailPoints: &hailPoints, windPoints: &windPoints)
            case .categorical:
                if let riskLabel = trimmed.components(separatedBy: .whitespaces).first,
                let risk = ConvectiveRisk(rawValue: riskLabel.lowercased()) { // We are assigning it this way since it allows functionality to work
                        flushOutlook(category: currentRiskCategory, currentPoints: &currentPoints, into: &outlookPolygons)
                        currentRiskCategory = riskLabel
                        let coords = trimmed.dropFirst(riskLabel.count).trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                        currentPoints += coords.compactMap(parseForecastCoordinate)
                } else if trimmed == "&&" {
                    flushOutlook(category: currentRiskCategory, currentPoints: &currentPoints, into: &outlookPolygons)
                    currentRiskCategory = nil
                } else {
                    currentPoints += parseLineOfCoords(trimmed)
                }
                
            default:
                continue
            }
        }
        
        // Final flush
        flushSevere(probability: currentProbability, currentPoints: &currentPoints, into: &severePoints)
        flushOutlook(category: currentRiskCategory, currentPoints: &currentPoints, into: &outlookPolygons)
        
#if DEBUG
        if tornPoints.isEmpty {
            print("⚠️ No tornado probabilities parsed.")
        }
        if hailPoints.isEmpty {
            print("⚠️ No hail probabilities parsed.")
        }
        if windPoints.isEmpty {
            print("⚠️ No wind probabilities parsed.")
        }
        if outlookPolygons.isEmpty {
            print("⚠️ No categorical outlook polygons parsed.")
        }
#endif
        
        // Add Tornado Probabilities
        severePolygons.append(SeverePolygon(type:.tornado, points: tornPoints))
        
        // Add Hail Probabilities
        severePolygons.append(SeverePolygon(type:.hail, points: hailPoints))
        
        // Add Wind Probabilities
        severePolygons.append(SeverePolygon(type:.wind, points: windPoints))
        
        return Points(valid: valid, issued: issued, severe: severePolygons, categorical: outlookPolygons)
    }
    
    private func handleSevereSectionLine(type: SevereRiskType, line: String, currentProbability: inout Double?, currentPoints: inout [CLLocationCoordinate2D], severePoints: inout [SeverePoint], tornPoints: inout [SeverePoint], hailPoints: inout [SeverePoint], windPoints: inout [SeverePoint]) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if let probabilityLabel = trimmed.components(separatedBy: .whitespaces).first,
           probabilityLabel.contains("."), let prob = Double(probabilityLabel) {
            flushSevere(probability: currentProbability, currentPoints: &currentPoints, into: &severePoints)
            currentProbability = prob
            let coords = trimmed.dropFirst(probabilityLabel.count).trimmingCharacters(in: .whitespaces)
            currentPoints += parseLineOfCoords(coords)
        } else if trimmed == "&&" {
            flushSevere(probability: currentProbability, currentPoints: &currentPoints, into: &severePoints)
            switch type {
            case .tornado: tornPoints = severePoints
            case .hail: hailPoints = severePoints
            case .wind: windPoints = severePoints
            }
            currentProbability = nil
            severePoints = []
        } else {
            currentPoints += parseLineOfCoords(trimmed)
        }
    }
    
    private func flushSevere(probability: Double?, currentPoints: inout [CLLocationCoordinate2D], into severePoints: inout [SeverePoint]) {
        guard let probability, !currentPoints.isEmpty else { return }
        let point = SeverePoint(probability: probability, points: currentPoints)
        severePoints.append(point)
        currentPoints.removeAll()
    }
    
    private func flushOutlook(category: String?, currentPoints: inout [CLLocationCoordinate2D], into outlookPolygons: inout [OutlookPolygon]) {
        guard let category, !currentPoints.isEmpty else { return }
        let polygon = OutlookPolygon(convectiveOutlook: category, points: currentPoints)
        outlookPolygons.append(polygon)
        currentPoints.removeAll()
    }
    
    private func parseLineOfCoords(_ line: String) -> [CLLocationCoordinate2D] {
        return line
            .components(separatedBy: .whitespaces)
            .compactMap(parseForecastCoordinate)
    }
}
