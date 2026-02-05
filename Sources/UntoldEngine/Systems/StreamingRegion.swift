//
//  StreamingRegion.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//

import Foundation
import simd

/// State of a streaming region
public enum StreamingState: String, Codable {
    case unloaded
    case loading
    case loaded
    case unloading
}

/// A region of the world that can be streamed in/out
public struct StreamingRegion: Identifiable {
    public let id: UUID
    public let bounds: AABB
    public let priority: Int // Higher = load first
    public let assetURLs: [URL] // What to load
    public var state: StreamingState
    public var loadedEntities: [EntityID] // Created entities
    public var estimatedMemorySize: Int // Bytes

    public init(
        id: UUID = UUID(),
        bounds: AABB,
        priority: Int = 0,
        assetURLs: [URL] = [],
        estimatedMemorySize: Int = 0
    ) {
        self.id = id
        self.bounds = bounds
        self.priority = priority
        self.assetURLs = assetURLs
        state = .unloaded
        loadedEntities = []
        self.estimatedMemorySize = estimatedMemorySize
    }
}
