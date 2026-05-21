//
//  LODConfig.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct LODConfig {
    private final class LODConfigStore: @unchecked Sendable {
        static let shared = LODConfigStore()

        private let lock = NSLock()
        private var config = LODConfig()

        private init() {}

        func get() -> LODConfig {
            lock.lock()
            let value = config
            lock.unlock()
            return value
        }

        func set(_ value: LODConfig) {
            lock.lock()
            config = value
            lock.unlock()
        }
    }

    public static var shared: LODConfig {
        get { LODConfigStore.shared.get() }
        set { LODConfigStore.shared.set(newValue) }
    }

    /// Default distance thresholds (in world units)
    public var lodDistances: [Float] = [
        50.0, // LOD0 -> LOD1
        100.0, // LOD1 -> LOD2
        200.0, // LOD2 -> LOD3
        500.0, // LOD3 -> LOD4 (or culled)
    ]

    /// Bias multiplier (1.0 = normal, 2.0 = switch 2x earlier)
    public var lodBias: Float = 1.0

    /// Hysteresis to prevent flickering ( add to distance when switching up)
    public var hysteresis: Float = 5.0

    // Enable smooth transitions - Not yet implemented
    public var enableFadeTransitions: Bool = false
    public var fadeTransitionTime: Float = 0.3

    /// Number of frames between full LOD entity queries.
    /// 1 = every frame, 4 = every 4 frames (default). Higher values reduce CPU overhead
    /// in tile-heavy scenes at the cost of slightly delayed LOD transitions.
    public var lodUpdateFrameInterval: Int = 4

    /// Camera must move at least this many world units since the last LOD update
    /// before a new update is forced ahead of the frame-interval throttle.
    public var minimumCameraDisplacementForLODUpdate: Float = 0.5
}
