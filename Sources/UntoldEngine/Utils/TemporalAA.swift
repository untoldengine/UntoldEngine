//
//  TemporalAA.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Lifecycle and per-frame state for the Temporal Anti-Aliasing resolve pass.
/// Texture creation lives in initTextureResources (RenderInitializer.swift).
/// The Halton jitter table lives in FuncUtils.swift.
/// GPU encoding is handled by taaRenderPass in RenderingSystem.swift.
final class TemporalAA: @unchecked Sendable {
    static let shared = TemporalAA()
    private init() {}

    private(set) var isSupported: Bool = false
    private var frameIndex: Int = 0

    /// Set to true on first use and after a history-invalidating event.
    /// The resolve shader outputs current-only when this is true, preventing
    /// garbage history from leaking into the first accumulated frame.
    private(set) var needsReset: Bool = true

    // MARK: - Lifecycle

    /// Called by initTextureResources once TAA textures have been allocated.
    /// Resets frameIndex so the Halton sequence always starts from sample 0,
    /// making multi-frame renders deterministic across test runs.
    func markReady() {
        frameIndex = 0
        needsReset = true
        isSupported = true
    }

    // MARK: - Per-frame helpers

    func currentJitter() -> simd_float2 {
        haltonJitterTable[frameIndex % haltonTableSize]
    }

    func advanceFrame() {
        frameIndex = (frameIndex + 1) % haltonTableSize
        needsReset = false
    }

    // MARK: - History invalidation

    /// Hard reset — flush history (teleport, scene cut, viewport resize).
    func reset() {
        needsReset = true
    }

    private var lastCameraPosition: simd_float3 = .zero

    /// Soft reset — auto-invalidate when the camera jumps more than `threshold` metres.
    func checkAndResetIfNeeded(cameraPosition: simd_float3, threshold: Float = 2.0) {
        if simd_length(cameraPosition - lastCameraPosition) > threshold { reset() }
        lastCameraPosition = cameraPosition
    }
}
