//
//  SpcRss.swift
//  SkyAware
//
//  This is a representation of the rss feed from SPC. All the products
//  share the same RSS structure, and have a different body format.
//
//  This class is for serializing the xml to object.
//
//  Created by Justin Rooks on 7/3/25.
//

import Foundation

struct RSS: Sendable {
    var channel: Channel?
}

struct Channel: Sendable {
    var title: String?
    var link: String?
    var description: String?
    var pubDate: String?
    var lastBuildDate: String?
    var rating: String?
    var docs: String?
    var ttl: String?
    var atomLink: AtomLink?
    var items: [Item] = []
}

struct AtomLink: Sendable {
    var href: String?
    var rel: String?
    var type: String?
}

struct Item: Sendable {
    var link: String?
    var title: String?
    var description: String?
    var pubDate: String?
    var guid: GUID?
}

struct GUID: Sendable {
    var value: String?
    var isPermaLink: String?
}
