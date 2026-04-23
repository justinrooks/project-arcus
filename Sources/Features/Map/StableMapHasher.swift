//
//  StableMapHasher.swift
//  SkyAware
//
//  Created by Codex on 4/21/26.
//

import Foundation

struct StableMapHasher: Sendable {
    private static let offsetBasis: UInt64 = 1_469_598_103_934_665_603
    private static let prime: UInt64 = 1_099_511_628_211

    private var state: UInt64 = Self.offsetBasis

    mutating func combine(_ value: String) {
        for byte in value.utf8 {
            state ^= UInt64(byte)
            state &*= Self.prime
        }
    }

    mutating func combine(_ value: String?) {
        combine(value ?? "")
    }

    mutating func combine<T: BinaryInteger>(_ value: T) {
        combine(String(Int64(truncatingIfNeeded: value)))
    }

    mutating func combine(_ value: Double, scale: Double = 1_000_000) {
        combine(Int64((value * scale).rounded()))
    }

    mutating func combine(_ coordinate: Coordinate2D) {
        combine(coordinate.latitude)
        combine(coordinate.longitude)
    }

    var intValue: Int {
        Int(truncatingIfNeeded: state)
    }

    var hexString: String {
        String(state, radix: 16, uppercase: false)
    }
}
