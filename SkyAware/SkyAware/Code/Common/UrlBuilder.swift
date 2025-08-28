//
//  UrlBuilder.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/25/25.
//

import Foundation

enum GeoJSONProduct: String {
    case categorical = "cat"       // this corresponds to the url builder, see buildUrl func below
    case tornado     = "torn"
    case hail        = "hail"
    case wind        = "wind"
}

enum RssProduct: String {
    case convective  = "spcacrss"  // Convective outlooks only
    case meso        = "spcmdrss"  // Meso discussions only
    case combined    = "spcrss"    // All the watches, warnings, mesos, convective, & fire
}

struct UrlBuilder {
    /// Builds out the URL required to get geojson data from the SPC
    /// the url is mostly consistent between each product, so this
    /// standardizes that creation process
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch geojson data for the provided product
    func getGeoJSONUrl(for product: GeoJSONProduct) throws -> URL {
        try makeSPCURL(path: "products/outlook/day1otlk_\(product.rawValue).lyr.geojson")
    }
    
    /// Builds out the URL required to get SPC RSS products
    /// - Parameter product: the product to fetch
    /// - Returns: a url to use to fetch rss data for the provided product
    func getRssUrl(for product: RssProduct) throws -> URL {
        try makeSPCURL(path: "products/\(product.rawValue).xml")
    }
    
    /// Build an absolute SPC URL from a relative path, or throw on failure.
    private func makeSPCURL(path: String) throws -> URL {
        let base = "https://www.spc.noaa.gov/"
        guard let url = URL(string: base + path) else { throw SpcError.invalidUrl }
        return url
    }
}
