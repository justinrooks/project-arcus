//
//  NWSWatchParser.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/8/25.
//

import Foundation
import OSLog

enum NWSGridPointParser {
    /// Decodes the provided Data into a GeoJSONFeatureCollection DTO
    /// - Parameter data: data stream to decode
    /// - Returns: a populated GeoJSONFeatureCollection DTO, or empty if there's a decoding error
    static func decode(from data: Data) -> NWSGridPoint? {
        let decoder = DecoderFactory.iso8601
        
        do {            
            return try decoder.decode(NWSGridPoint.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSGridPointParser")
            logger.error("GeoJSON decoding failed: Data corrupted – \(context.debugDescription, privacy: .public)")
            return nil
        } catch let DecodingError.keyNotFound(key, context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSGridPointParser")
            logger.error("GeoJSON decoding failed: Missing key '\(key.stringValue, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return nil
        } catch let DecodingError.typeMismatch(type, context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSGridPointParser")
            logger.error("GeoJSON decoding failed: Type mismatch for type '\(type, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return nil
        } catch let DecodingError.valueNotFound(value, context) {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSGridPointParser")
            logger.error("GeoJSON decoding failed: Missing value '\(value, privacy: .public)' – \(context.debugDescription, privacy: .public)")
            return nil
        } catch {
            let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NWSGridPointParser")
            logger.error("Unexpected GeoJSON decode error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
