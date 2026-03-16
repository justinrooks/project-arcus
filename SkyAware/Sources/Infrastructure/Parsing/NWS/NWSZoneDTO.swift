//
//  NWSZoneDTO.swift
//  SkyAware
//
//  Created by Codex on 3/15/26.
//

import Foundation

/// Minimal zone DTO for payloads where only properties.type and properties.name matter.
struct NWSZoneDTO: Decodable, Sendable {
    let properties: Properties

    var type: String { properties.type }
    var name: String { properties.name }

    struct Properties: Decodable, Sendable {
        let type: String
        let name: String
    }
}
