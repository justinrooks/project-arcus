//
//  SpcSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

protocol SpcSyncing: Sendable {//where Self: Actor {
    func sync() async -> Void
    func syncMapProducts() async -> Void
    func syncTextProducts() async -> Void
}
