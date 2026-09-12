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
    private var _disableWorkingSetBudget = false
    private var _disableScreenWeightedQuotas = false
    private var _disablePaging = false
    private var _freezePaging = false
    private var _disablePageFade = false
    private var _residencyDebugTint = false
    private var _gaussianLevelMode = GaussianLevelMode.auto
    private var _disableLevelCrossFade = false
    private var _levelDebugTint = false

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
    /// so the fused per-chunk pass walks the whole asset. The entity stays on the chunk path —
    /// the per-splat kernel is still `gaussianChunkDecodePreprocess`, dispatched over every
    /// chunk, not the whole-buffer `gaussianFrustumCull` a `.ply` runs. With the budget
    /// unlimited the frame is the same either way — the chunk cull only skips splats the
    /// per-splat test would reject — which is what this switch is for: an A/B of the chunk
    /// stage's cost and of that guarantee. Under a budget the chunks no view keeps carry the
    /// minimum screen area, so they are cut first, and when they hold more than the climb's tail
    /// of the request they set the climb density, so a lift to a fitting budget takes the kept
    /// chunks to whole in one frame.
    public var disableChunkCull: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableChunkCull }
        set { lock.lock(); _disableChunkCull = newValue; lock.unlock() }
    }

    /// Sizes the frame's shared working set to the resident splat total instead of the budget
    /// (`GaussianRuntimeLimits.workingSetSplats`) and grants every visible chunk its whole splat
    /// count, so nothing is ever truncated: the pre-budget behaviour, for an A/B of the budget's
    /// cost and of what it cuts.
    public var disableWorkingSetBudget: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableWorkingSetBudget }
        set { lock.lock(); _disableWorkingSetBudget = newValue; lock.unlock() }
    }

    /// Grants every visible chunk the same fraction of its splats, floor(scale × count), instead of
    /// weighting the quotas by screen area (the density cap): the pre-weighting rule, byte for
    /// byte, for an A/B of what the weighting moves. Note that with `disableChunkCull` and this
    /// off, chunks no view keeps carry the minimum screen area and are cut first on a truncated
    /// frame.
    public var disableScreenWeightedQuotas: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableScreenWeightedQuotas }
        set { lock.lock(); _disableScreenWeightedQuotas = newValue; lock.unlock() }
    }

    /// Loads every `.untoldgs` whole-resident whatever its size, so no entity pages (takes
    /// effect at the next load): the pre-paging behaviour, for an A/B of what the pool costs and
    /// what its fill-in shows.
    public var disablePaging: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disablePaging }
        set { lock.lock(); _disablePaging = newValue; lock.unlock() }
    }

    /// Holds every paged entity's resident set as it is: no read is issued, nothing is evicted
    /// (reads already in flight still land). With the fade complete the image is then a
    /// function of the camera alone — the determinism and bisecting switch.
    public var freezePaging: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _freezePaging }
        set { lock.lock(); _freezePaging = newValue; lock.unlock() }
    }

    /// Shows an arriving tier at once instead of fading it in over
    /// `GaussianPagingPolicy.fadeFrames` frames (tests, the twin comparison).
    public var disablePageFade: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disablePageFade }
        set { lock.lock(); _disablePageFade = newValue; lock.unlock() }
    }

    /// Tints every splat of a paged entity by its chunk's resident fraction — green whole,
    /// yellow deep, red head-only — for the editor.
    public var residencyDebugTint: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _residencyDebugTint }
        set { lock.lock(); _residencyDebugTint = newValue; lock.unlock() }
    }

    /// How a `.untoldgs` entity with per-chunk coarse levels chooses each chunk's level: `.auto`
    /// runs the level rule (a far or non-resident chunk draws a merged coarse level), `.fineOnly`
    /// draws the fine records only — byte for byte the frame of a file without a coarse section,
    /// the A/B of what the levels change — `.coarseOnly` draws every chunk at its coarsest
    /// available level (the twin comparison).
    public var gaussianLevelMode: GaussianLevelMode {
        get { lock.lock(); defer { lock.unlock() }; return _gaussianLevelMode }
        set { lock.lock(); _gaussianLevelMode = newValue; lock.unlock() }
    }

    /// Switches a chunk's level at once instead of cross-fading the two levels over
    /// `GaussianPagingPolicy.fadeFrames` frames (tests, the twin comparison).
    public var disableLevelCrossFade: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _disableLevelCrossFade }
        set { lock.lock(); _disableLevelCrossFade = newValue; lock.unlock() }
    }

    /// Tints every splat of an entity with coarse levels by the level its chunk draws — white
    /// fine, yellow level 1, red level 2 — for the editor (over the residency tint when both are on).
    public var levelDebugTint: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _levelDebugTint }
        set { lock.lock(); _levelDebugTint = newValue; lock.unlock() }
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

/// The level modes of `GaussianDebugOptions.gaussianLevelMode`
/// (`GaussianChunkLevelConstants.levelMode`, `GaussianChunkLevelMode` in ShaderTypes.h).
public enum GaussianLevelMode: UInt32, Sendable, CaseIterable {
    /// The level rule.
    case auto = 0
    /// Every chunk fine: the frame of a file without a coarse section.
    case fineOnly = 1
    /// Every chunk at its coarsest available level.
    case coarseOnly = 2
}
