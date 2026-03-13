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

public enum SpatialDebugBatchCellColorMode: String {
    case plain
    case culling
    case lod
    case cell
}

/// Runtime toggles for spatial debug visualization.
public final class SpatialDebugVisualization: @unchecked Sendable {
    public static let shared = SpatialDebugVisualization()

    private let lock = NSLock()

    /// Master switch for all spatial debug rendering.
    private var _enabled: Bool = false
    public var enabled: Bool {
        get {
            lock.lock()
            let value = _enabled
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _enabled = newValue
            lock.unlock()
        }
    }

    /// Draw octree leaf node bounds.
    private var _showOctreeLeafBounds: Bool = false
    public var showOctreeLeafBounds: Bool {
        get {
            lock.lock()
            let value = _showOctreeLeafBounds
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _showOctreeLeafBounds = newValue
            lock.unlock()
        }
    }

    /// Max number of leaf nodes rendered per frame (0 = unlimited).
    private var _maxLeafNodeCount: Int = 2000
    public var maxLeafNodeCount: Int {
        get {
            lock.lock()
            let value = _maxLeafNodeCount
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _maxLeafNodeCount = newValue
            lock.unlock()
        }
    }

    /// When true, include only occupied octree leaves.
    private var _octreeLeafOccupiedOnly: Bool = true
    public var octreeLeafOccupiedOnly: Bool {
        get {
            lock.lock()
            let value = _octreeLeafOccupiedOnly
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _octreeLeafOccupiedOnly = newValue
            lock.unlock()
        }
    }

    /// Color mode for octree leaf bounds.
    private var _octreeLeafColorMode: SpatialDebugLeafColorMode = .plain
    public var octreeLeafColorMode: SpatialDebugLeafColorMode {
        get {
            lock.lock()
            let value = _octreeLeafColorMode
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _octreeLeafColorMode = newValue
            lock.unlock()
        }
    }

    /// Color shaded renderables by active LOD index.
    private var _colorRenderablesByLOD: Bool = false
    public var colorRenderablesByLOD: Bool {
        get {
            lock.lock()
            let value = _colorRenderablesByLOD
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _colorRenderablesByLOD = newValue
            lock.unlock()
        }
    }

    /// Draw static batch cell bounds.
    private var _showStaticBatchCellBounds: Bool = false
    public var showStaticBatchCellBounds: Bool {
        get {
            lock.lock()
            let value = _showStaticBatchCellBounds
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _showStaticBatchCellBounds = newValue
            lock.unlock()
        }
    }

    /// Max number of static batch cells rendered per frame (0 = unlimited).
    private var _maxStaticBatchCellCount: Int = 2000
    public var maxStaticBatchCellCount: Int {
        get {
            lock.lock()
            let value = _maxStaticBatchCellCount
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _maxStaticBatchCellCount = newValue
            lock.unlock()
        }
    }

    /// Color mode for static batch cell bounds.
    private var _staticBatchCellColorMode: SpatialDebugBatchCellColorMode = .plain
    public var staticBatchCellColorMode: SpatialDebugBatchCellColorMode {
        get {
            lock.lock()
            let value = _staticBatchCellColorMode
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _staticBatchCellColorMode = newValue
            lock.unlock()
        }
    }

    private init() {}

    public func configureOctreeLeafBounds(
        enabled: Bool,
        maxLeafNodeCount: Int = 2000,
        occupiedOnly: Bool = true,
        colorMode: SpatialDebugLeafColorMode = .plain
    ) {
        lock.lock()
        _enabled = enabled || _showStaticBatchCellBounds || _colorRenderablesByLOD
        _showOctreeLeafBounds = enabled
        _maxLeafNodeCount = max(0, maxLeafNodeCount)
        _octreeLeafOccupiedOnly = occupiedOnly
        _octreeLeafColorMode = colorMode
        lock.unlock()
    }

    public func configureStaticBatchCellBounds(
        enabled: Bool,
        maxCellCount: Int = 2000,
        colorMode: SpatialDebugBatchCellColorMode = .plain
    ) {
        lock.lock()
        _enabled = _showOctreeLeafBounds || enabled || _colorRenderablesByLOD
        _showStaticBatchCellBounds = enabled
        _maxStaticBatchCellCount = max(0, maxCellCount)
        _staticBatchCellColorMode = colorMode
        lock.unlock()
    }

    public func configureLODLevelColoring(enabled: Bool) {
        lock.lock()
        _colorRenderablesByLOD = enabled
        _enabled = _showOctreeLeafBounds || _showStaticBatchCellBounds || _colorRenderablesByLOD
        lock.unlock()
    }

    public func disableAll() {
        lock.lock()
        _enabled = false
        _showOctreeLeafBounds = false
        _showStaticBatchCellBounds = false
        _colorRenderablesByLOD = false
        lock.unlock()
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

/// Enable/disable static batch cell bounds visualization.
public func setStaticBatchCellBoundsDebug(
    enabled: Bool,
    maxCellCount: Int = 2000,
    colorMode: SpatialDebugBatchCellColorMode = .plain
) {
    SpatialDebugVisualization.shared.configureStaticBatchCellBounds(
        enabled: enabled,
        maxCellCount: maxCellCount,
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

/// Enable/disable LOD level debug coloring for renderables.
public func setLODLevelDebug(enabled: Bool) {
    SpatialDebugVisualization.shared.configureLODLevelColoring(enabled: enabled)
}
