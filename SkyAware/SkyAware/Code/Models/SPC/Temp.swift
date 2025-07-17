//
//  Temp.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/14/25.
//

import Foundation

// MARK: WORKING PARSING LOGIC FOR TORNADO SEVERE POINTS FILE. PointsParser.swift ~line 102
//                if let probabilityLabel = trimmed.components(separatedBy: .whitespaces).first, probabilityLabel.contains(".") { // if we have a probability
//                    flushSevere(probability: currentProbability, currentPoints: &currentPoints, into: &severePoints)
//                    currentProbability = Double(probabilityLabel)
//                    let coords = trimmed.dropFirst(probabilityLabel.count).trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
//                    currentPoints += coords.compactMap(parseForecastCoordinate)
//                } else if trimmed == "&&" { // Else if its the end of the section
//                    flushSevere(probability: currentProbability, currentPoints: &currentPoints, into: &severePoints)
//                    tornPoints = severePoints
//                    currentProbability = nil
//                    severePoints = []
//                } else { // Else its a line of the probability
//                    currentPoints += parseLineOfCoords(trimmed)
//                }
