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

    /// Enable dithered cross-fade transitions for entity-level LOD switches and
    /// tile representation handoffs.
    public var enableFadeTransitions: Bool = false
    public var fadeTransitionTime: Float = 0.3

    /// Number of frames between full LOD entity queries.
    /// 1 = every frame, 4 = every 4 frames (default). Higher values reduce CPU overhead
    /// in tile-heavy scenes at the cost of slightly delayed LOD transitions.
    public var lodUpdateFrameInterval: Int = 4

    /// Camera must move at least this many world units since the last LOD update
    /// before a new update is forced ahead of the frame-interval throttle.
    public var minimumCameraDisplacementForLODUpdate: Float = 0.5

    /// An entity's distance-to-camera must change by at least this many world units since its
    /// own last LOD evaluation before a refresh is forced ahead of the frame-interval throttle
    /// — mirrors `minimumCameraDisplacementForLODUpdate` but for the target moving instead of
    /// the camera (e.g. dragging a Gaussian splat prop while the camera stays put, which the
    /// camera-only fast path can't see).
    public var minimumEntityDisplacementForLODUpdate: Float = 0.5

    /// Ceiling on `estimatedGaussianOverdraw` (mean blended fragments per pixel across a
    /// Gaussian entity's screen footprint) before `GaussianLODSystem` forces a coarser tier
    /// than pure distance-based selection would pick. This is a starting guess, not a derived
    /// constant — the engine's serial TBDR blend caps at `kGaussianMaxBlendedSplatsPerPixel`
    /// (64) per pixel, but sustained GPU frame-time overrun (the actual failure mode this
    /// guards against) was observed well below that cap. Tune on-device by watching GPU frame
    /// time while varying this value; only takes effect for LOD levels with a non-nil
    /// `GaussianLODLevel.meanSquaredSplatExtent` supplied.
    public var gaussianOverdrawBudget: Float = 12.0
}
