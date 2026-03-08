//
//  SpatialDebugVisualization.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum SpatialDebugLeafColorMode: String {
    case plain
    case residency
    case culling
}

/// Runtime toggles for spatial debug visualization.
public final class SpatialDebugVisualization {
    public static let shared = SpatialDebugVisualization()

    /// Master switch for all spatial debug rendering.
    public var enabled: Bool = false

    /// Draw octree leaf node bounds.
    public var showOctreeLeafBounds: Bool = false

    /// Max number of leaf nodes rendered per frame (0 = unlimited).
    public var maxLeafNodeCount: Int = 2000

    /// When true, include only occupied octree leaves.
    public var octreeLeafOccupiedOnly: Bool = true

    /// Color mode for octree leaf bounds.
    public var octreeLeafColorMode: SpatialDebugLeafColorMode = .plain

    private init() {}

    public func configureOctreeLeafBounds(
        enabled: Bool,
        maxLeafNodeCount: Int = 2000,
        occupiedOnly: Bool = true,
        colorMode: SpatialDebugLeafColorMode = .plain
    ) {
        self.enabled = enabled
        showOctreeLeafBounds = enabled
        self.maxLeafNodeCount = max(0, maxLeafNodeCount)
        octreeLeafOccupiedOnly = occupiedOnly
        octreeLeafColorMode = colorMode
    }

    public func disableAll() {
        enabled = false
        showOctreeLeafBounds = false
    }
}

/// Enable/disable octree leaf bounds visualization.
public func setOctreeLeafBoundsDebug(
    enabled: Bool,
    maxLeafNodeCount: Int = 2000,
    occupiedOnly: Bool = true,
    colorMode: SpatialDebugLeafColorMode = .plain
) {
    SpatialDebugVisualization.shared.configureOctreeLeafBounds(
        enabled: enabled,
        maxLeafNodeCount: maxLeafNodeCount,
        occupiedOnly: occupiedOnly,
        colorMode: colorMode
    )
}

/// Backward-compatible overload.
public func setOctreeLeafBoundsDebug(
    enabled: Bool,
    maxLeafNodeCount: Int = 2000,
    occupiedOnly: Bool = true,
    colorByStreamingResidency: Bool
) {
    SpatialDebugVisualization.shared.configureOctreeLeafBounds(
        enabled: enabled,
        maxLeafNodeCount: maxLeafNodeCount,
        occupiedOnly: occupiedOnly,
        colorMode: colorByStreamingResidency ? .residency : .plain
    )
}

/// Disable all spatial debug visualization.
public func disableSpatialDebugVisualization() {
    SpatialDebugVisualization.shared.disableAll()
}
