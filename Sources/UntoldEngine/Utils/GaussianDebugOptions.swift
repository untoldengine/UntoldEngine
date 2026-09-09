//
//  GaussianDebugOptions.swift
//  UntoldEngine
//
//  Runtime switches that turn off individual stages of the Gaussian splat pipeline so an
//  artefact can be bisected while the scene is running (the editor exposes them). All default
//  to the normal behaviour; none of them is meant for shipping content.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation

public final class GaussianDebugOptions: @unchecked Sendable {
    public static let shared = GaussianDebugOptions()

    private let lock = NSLock()
    private var _disableHZBOcclusionCull = false
    private var _disableOpaqueDepthTest = false
    private var _disableBlendCap = false
    private var _disableOccluderShell = false
    private var _disableChunkCull = false

    /// Skips the per-splat test against the previous frame's HZB depth pyramid in
    /// `gaussianFrustumCull`. The frustum test still runs.
    public var disableHZBOcclusionCull: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableHZBOcclusionCull }
        set { lock.lock(); _disableHZBOcclusionCull = newValue; lock.unlock() }
    }

    /// Skips the per-fragment test against the opaque scene depth snapshot in the splat draw,
    /// so splats are never hidden by meshes, gizmos or the editor grid.
    public var disableOpaqueDepthTest: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableOpaqueDepthTest }
        set { lock.lock(); _disableOpaqueDepthTest = newValue; lock.unlock() }
    }

    /// Lifts the per-pixel cap on blended splats (`kGaussianMaxBlendedSplatsPerPixel`) to the
    /// counter's maximum, so every sorted splat that reaches a pixel is blended.
    public var disableBlendCap: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableBlendCap }
        set { lock.lock(); _disableBlendCap = newValue; lock.unlock() }
    }

    /// Skips the depth-only occluder shells (`meshOccluderShell` pass, `MeshOccluderComponent`),
    /// so a splat standing in for a mesh is no longer hidden behind the mesh surface.
    public var disableOccluderShell: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableOccluderShell }
        set { lock.lock(); _disableOccluderShell = newValue; lock.unlock() }
    }

    /// Makes the chunk-level cull of `.untoldgs` entities (`gaussianChunkCull`) keep every chunk,
    /// so the per-splat pass walks the whole asset. The entity stays on the chunk path — the
    /// per-splat kernel is still `gaussianChunkSplatCull`, dispatched over every chunk, not the
    /// whole-buffer `gaussianFrustumCull` a `.ply` runs. The frame is the same either way — the
    /// chunk cull only skips splats the per-splat test would reject — which is what this switch
    /// is for: an A/B of the chunk stage's cost and of that guarantee.
    public var disableChunkCull: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableChunkCull }
        set { lock.lock(); _disableChunkCull = newValue; lock.unlock() }
    }

    /// The per-draw constants the splat fragment shader reads (see `GaussianTBDRDrawDebug`).
    var drawConstants: GaussianTBDRDrawDebug {
        var constants = GaussianTBDRDrawDebug()
        constants.maxBlendedSplatsPerPixel = disableBlendCap ? 255 : UInt32(kGaussianMaxBlendedSplatsPerPixelDefault)
        constants.skipOpaqueDepthTest = disableOpaqueDepthTest ? 1 : 0
        return constants
    }
}

/// Mirrors `kGaussianMaxBlendedSplatsPerPixel` in Gaussians.metal — the normal per-pixel cap.
let kGaussianMaxBlendedSplatsPerPixelDefault = 64
