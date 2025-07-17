//
//  SpcError.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

enum SpcError: Error {
    case missingData
    case networkError
    case parsingError
}

extension SpcError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return "SPC data is missing."
        case .networkError:
            return "SPC data network error."
        case .parsingError:
            return "SPC data parsing error."
        }
    }
}
