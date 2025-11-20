//
//  AlertProtocol.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import Foundation

protocol AlertItem: Identifiable, Hashable {
    var number: Int { get }
    var title: String { get }
    var summary: String { get }
    var issued: Date { get }
    var link: URL { get }
    var alertType: AlertType { get }
}

enum AlertType: Codable {
    case watch
    case mesoscale
}
