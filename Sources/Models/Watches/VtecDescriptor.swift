//
//  VtecDescriptor.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/23/26.
//

import Foundation

/// Parsed representation of a single VTEC line like:
/// /O.CON.KBOU.CW.Y.0001.260123T1000Z-260125T1600Z/
struct VTECDescriptor: Equatable, Hashable, Sendable {
    /// Full raw VTEC string as received.
    let raw: String

    /// One-letter action code: O, T, E, etc.
    let action: String

    /// Status code: NEW, CON, CAN, EXP, EXA, EXT, COR, etc.
    let status: String

    /// WFO office, e.g. KBOU
    let office: String

    /// Phenomenon code, e.g. CW, SV, TO, etc.
    let phenomenon: String

    /// Significance code, e.g. W, Y, A, etc.
    let significance: String

    /// Event number, usually 4 digits, e.g. 0001
    let eventNumber: String

    /// Start time token, e.g. 260123T1000Z or 000000T0000Z (unknown)
    let beginTimeToken: String

    /// End time token, e.g. 260125T1600Z
    let endTimeToken: String

    /// Your canonical / stable event key for identity.
    var eventKey: String {
        "\(office)-\(phenomenon)-\(significance)-\(eventNumber)"
    }
}
