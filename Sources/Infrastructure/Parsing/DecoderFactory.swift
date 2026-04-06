//
//  DecoderFactory.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/18/25.
//

import Foundation

enum DecoderFactory {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
    
    static var base: JSONDecoder {
        JSONDecoder()
    }
}
