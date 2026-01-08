//
//  NWSWatchParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/8/25.
//

import Foundation
import OSLog

enum NWSWatchParser {
    /// Decodes the provided Data into a GeoJSONFeatureCollection DTO
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    static func decode(from data: Data) -> NWSWatchJson? {
        let decoder = DecoderFactory.iso8601
        
        do {
            return try decoder.decode(NWSWatchJson.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSWatchParser")
            logger.error("GeoJSON decoding failed: Data corrupted – \(context.debugDescription)")
            return nil
        } catch let DecodingError.keyNotFound(key, context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSWatchParser")
            logger.error("GeoJSON decoding failed: Missing key '\(key.stringValue)' – \(context.debugDescription)")
            return nil
        } catch let DecodingError.typeMismatch(type, context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSWatchParser")
            logger.error("GeoJSON decoding failed: Type mismatch for type '\(type)' – \(context.debugDescription)")
            return nil
        } catch let DecodingError.valueNotFound(value, context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSWatchParser")
            logger.error("GeoJSON decoding failed: Missing value '\(value)' – \(context.debugDescription)")
            return nil
        } catch {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSWatchParser")
            logger.error("Unexpected GeoJSON decode error: \(error.localizedDescription)")
            return nil
        }
    }
}
