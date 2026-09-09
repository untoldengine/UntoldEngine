//
//  GaussianChunkCull.swift
//  UntoldEngine
//
//  CPU side of the per-chunk path of .untoldgs entities: the chunk-level cull
//  (GaussianChunkCull.metal), the working-set budget and its per-chunk quotas
//  (GaussianWorkingSetBudget.metal) and the fused decode/test/project/compact pass
//  (GaussianChunkPreprocess.metal) — the per-slot buffers a chunked entity carries, the
//  per-frame constants, the encodes, and CPU mirrors of the chunk test, the quota and the
//  opacity band for tests and callers that want to predict what the GPU keeps.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd

/// Mirrors `kGaussianQuadSigma` in Gaussians.metal: how many standard deviations the rendered
/// quad extends along each principal axis, and so how far a chunk's box is padded per unit of
/// the largest splat scale it holds.
let kGaussianQuadSigmaDefault: Float = 3.5

/// Guard band of the per-splat and chunk culls, as a fraction of the half clip extent: a centre
/// (or box) up to 25 % outside the view still counts as visible, so splats whose footprint
/// reaches into the frame from just off-screen are kept.
let gaussianCullClipGuardBand: Float = 0.25

/// NDC depth bias of the HZB tests, shared by the mesh cull, the per-splat cull and the chunk cull.
let gaussianCullHZBOcclusionBias: Float = 0.02

/// Mirrors `kGaussianOpacityBandFraction` (GaussianChunkPreprocess.metal): the ranks of a
/// truncated chunk from this fraction of its quota up to the quota fade linearly to zero.
let gaussianOpacityBandFraction: Float = 0.8

/// The fraction of the working set the quotas aim for, leaving room for the frame's rounding.
let gaussianBudgetHeadroom: Float = 0.98

/// The largest relative rise of the budget scale from one frame to the next; a fall is taken at
/// once (a lower scale never overflows the set, a lagging one would).
let gaussianBudgetMaxStepFraction: Float = 0.1

/// The smallest absolute rise of the budget scale per frame, so a climb from a low scale (a cut
/// from a dense view to one that fits the budget) does not crawl: from 0.06 to 1 in about 17
/// frames instead of 30.
let gaussianBudgetMinStep: Float = 0.05

/// CPU mirror of the chunk test in `gaussianChunkCull` (GaussianChunkCull.metal), without the
/// HZB part: the chunk's centre AABB padded by `extentPadding(logScaleMax:)` on every side,
/// tested against the guard-banded clip volume of each view; visible if any view keeps it. The
/// test is conservative in the same way as the kernel — a box is rejected only when all eight
/// corners lie beyond the same clip plane — so any splat centre the per-splat cull keeps lies in
/// a chunk this keeps.
enum GaussianChunkCullMath {
    /// How far the largest splat of a chunk can reach from its centre along any axis.
    static func extentPadding(logScaleMax: Float) -> Float {
        kGaussianQuadSigmaDefault * exp(logScaleMax)
    }

    /// The clip-plane test of one box against one view-projection (model matrix folded in).
    static func boxPassesClipPlanes(
        boxMin: simd_float3,
        boxMax: simd_float3,
        viewProjection: simd_float4x4,
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> Bool {
        let limit = max(0, 1 + clipGuardBand)
        var outsideEveryCorner: UInt32 = 0x7F
        for i in 0 ..< 8 {
            let corner = simd_float3(
                (i & 1) != 0 ? boxMax.x : boxMin.x,
                (i & 2) != 0 ? boxMax.y : boxMin.y,
                (i & 4) != 0 ? boxMax.z : boxMin.z
            )
            let c = simd_mul(viewProjection, simd_float4(corner, 1))
            var outside: UInt32 = 0
            if c.w <= 0 { outside |= 0x01 }
            if c.x < -c.w * limit { outside |= 0x02 }
            if c.x > c.w * limit { outside |= 0x04 }
            if c.y < -c.w * limit { outside |= 0x08 }
            if c.y > c.w * limit { outside |= 0x10 }
            if c.z < -c.w * clipGuardBand { outside |= 0x20 }
            if c.z > c.w * limit { outside |= 0x40 }
            outsideEveryCorner &= outside
        }
        return outsideEveryCorner == 0
    }

    /// The chunk's padded box, as the kernel builds it from the decode constants.
    static func paddedBox(aabbMin: simd_float3, aabbMax: simd_float3, logScaleMax: Float) -> (min: simd_float3, max: simd_float3) {
        let pad = extentPadding(logScaleMax: logScaleMax)
        return (aabbMin - simd_float3(repeating: pad), aabbMax + simd_float3(repeating: pad))
    }

    /// Visible if the padded box passes any of `viewProjections` (the frame's eyes; one in mono).
    static func chunkIsVisible(
        aabbMin: simd_float3,
        aabbMax: simd_float3,
        logScaleMax: Float,
        viewProjections: [simd_float4x4],
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> Bool {
        let box = paddedBox(aabbMin: aabbMin, aabbMax: aabbMax, logScaleMax: logScaleMax)
        return viewProjections.contains { viewProjection in
            boxPassesClipPlanes(boxMin: box.min, boxMax: box.max, viewProjection: viewProjection, clipGuardBand: clipGuardBand)
        }
    }

    /// The same for a chunk entry of the file index.
    static func chunkIsVisible(
        _ entry: UntoldGSChunkEntry,
        viewProjections: [simd_float4x4],
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> Bool {
        chunkIsVisible(
            aabbMin: entry.aabbMin,
            aabbMax: entry.aabbMax,
            logScaleMax: entry.logScaleMax,
            viewProjections: viewProjections,
            clipGuardBand: clipGuardBand
        )
    }

    // MARK: Budget mirrors (GaussianWorkingSetBudget.metal, GaussianChunkPreprocess.metal)

    /// The scale a frame targets: 1 while the chunked request fits what the whole-buffer
    /// entities' `reservedSplats` leave of the budget, else the fraction of every visible chunk
    /// that fits the headroom's share of that room (0 when nothing is left).
    static func targetScale(requestedSplats: Int, budget: Int, reservedSplats: Int = 0, headroom: Float = gaussianBudgetHeadroom) -> Float {
        guard requestedSplats > budget - reservedSplats else { return 1 }
        let room = max(headroom * Float(budget) - Float(reservedSplats), 0)
        return min(1, room / Float(requestedSplats))
    }

    /// The scale applied after the hysteresis: the target when it is at or below the previous
    /// frame's scale, else the previous scale raised by at most max(`maxStepFraction` × previous,
    /// `minStep`); the first frame, and a frame with no chunked request (`requestedSplats` 0,
    /// nothing drawn under the scale), take the target.
    static func smoothedScale(
        target: Float,
        previous: Float?,
        requestedSplats: Int = 1,
        maxStepFraction: Float = gaussianBudgetMaxStepFraction,
        minStep: Float = gaussianBudgetMinStep
    ) -> Float {
        guard let previous, requestedSplats > 0 else { return target }
        let clamped = min(max(previous, 0), 1)
        guard target > clamped else { return target }
        let step = max(clamped * maxStepFraction, minStep)
        return min(target, clamped + step)
    }

    /// Frames a rise from `previous` to `target` takes through `smoothedScale`.
    static func framesToReach(target: Float, from previous: Float) -> Int {
        var scale = previous
        var frames = 0
        while scale < target, frames < 10000 {
            scale = smoothedScale(target: target, previous: scale)
            frames += 1
        }
        return frames
    }

    /// A visible chunk's quota at `scale`: floor(scale × splatCount), never above the count.
    static func quota(scale: Float, splatCount: UInt32) -> UInt32 {
        guard scale < 1 else { return splatCount }
        return min(splatCount, UInt32(max(0, floor(scale * Float(splatCount)))))
    }

    /// The opacity multiplier of rank `rank` in a chunk granted `quota` of its `splatCount`.
    static func opacityBandFactor(rank: UInt32, quota: UInt32, splatCount: UInt32) -> Float {
        guard quota < splatCount else { return 1 }
        let bandStart = UInt32(gaussianOpacityBandFraction * Float(quota))
        guard rank >= bandStart, quota > bandStart else { return 1 }
        return Float(quota - rank) / Float(quota - bandStart)
    }
}

/// The visible-chunk record with `visibleChunks` chunks holding `visibleSplats` splats counted as
/// visible — a freshly loaded entity's state until its first chunk cull, with every chunk listed.
func makeGaussianVisibleChunkSet(visibleChunks: UInt32, visibleSplats: UInt32) -> GaussianVisibleSet {
    var set = GaussianVisibleSet()
    set.visibleCount = visibleSplats
    set.threadgroupCount = visibleChunks
    set.overflowCount = 0
    set.threadgroupsPerGrid = (visibleChunks, 1, 1)
    set.vertexCount = 4
    set.instanceCount = visibleSplats
    set.vertexStart = 0
    set.baseInstance = 0
    return set
}

/// Allocates the per-in-flight-slot visible-chunk list and record of a chunk table, each slot
/// seeded with every chunk visible. Returns nil when a buffer cannot be made.
func allocateGaussianVisibleChunkBuffers(for table: GaussianChunkTable) -> GaussianChunkTable? {
    guard let device = renderInfo.device else { return nil }
    let entries: [GaussianVisibleChunk] = table.index.chunks.enumerated().map { index, chunk in
        GaussianVisibleChunk(chunkIndex: UInt32(index), splatCount: chunk.splatCount, quota: chunk.splatCount, _pad0: 0)
    }
    let splatTotal = entries.reduce(UInt32(0)) { $0 &+ $1.splatCount }
    let listLength = max(1, entries.count) * MemoryLayout<GaussianVisibleChunk>.stride

    var result = table
    result.visibleChunks = []
    result.visibleChunkSets = []
    for slot in 0 ..< maxInFlightCommandBuffers {
        guard let list = device.makeBuffer(length: listLength, options: .storageModeShared),
              let set = device.makeBuffer(length: MemoryLayout<GaussianVisibleSet>.stride, options: .storageModeShared)
        else { return nil }
        list.label = "Gaussian Visible Chunks \(slot)"
        set.label = "Gaussian Visible Chunk Set \(slot)"
        if !entries.isEmpty {
            list.contents().copyMemory(from: entries, byteCount: entries.count * MemoryLayout<GaussianVisibleChunk>.stride)
        }
        set.contents().storeBytes(
            of: makeGaussianVisibleChunkSet(visibleChunks: UInt32(entries.count), visibleSplats: splatTotal),
            as: GaussianVisibleSet.self
        )
        result.visibleChunks.append(list)
        result.visibleChunkSets.append(set)
    }
    return result
}

/// The compiled kernels of the per-chunk path, or nil while any of them is missing (a `.untoldgs`
/// is then decoded at load into the whole-buffer path like a `.ply`).
struct GaussianChunkCullPipelineStates {
    let reset: MTLComputePipelineState
    let cull: MTLComputePipelineState
    let finalize: MTLComputePipelineState
    /// `gaussianChunkDecodePreprocess`: the fused decode, test, project and compact.
    let decodePreprocess: MTLComputePipelineState
    let resetBudget: MTLComputePipelineState
    let budgetScale: MTLComputePipelineState
    let chunkQuotas: MTLComputePipelineState
    let publishBudget: MTLComputePipelineState
    /// `gaussianReserveBudgetSplats`: a whole-buffer entity's visible count, reserved before the quotas.
    let reserveBudget: MTLComputePipelineState

    static func current() -> GaussianChunkCullPipelineStates? {
        guard gaussianResetVisibleChunkSetPipeline.success,
              gaussianChunkCullPipeline.success,
              gaussianFinalizeVisibleChunksPipeline.success,
              gaussianChunkDecodePreprocessPipeline.success,
              gaussianResetBudgetRequestPipeline.success,
              gaussianComputeBudgetScalePipeline.success,
              gaussianComputeChunkQuotasPipeline.success,
              gaussianPublishBudgetStatePipeline.success,
              gaussianReserveBudgetSplatsPipeline.success,
              let reset = gaussianResetVisibleChunkSetPipeline.pipelineState,
              let cull = gaussianChunkCullPipeline.pipelineState,
              let finalize = gaussianFinalizeVisibleChunksPipeline.pipelineState,
              let decodePreprocess = gaussianChunkDecodePreprocessPipeline.pipelineState,
              let resetBudget = gaussianResetBudgetRequestPipeline.pipelineState,
              let budgetScale = gaussianComputeBudgetScalePipeline.pipelineState,
              let chunkQuotas = gaussianComputeChunkQuotasPipeline.pipelineState,
              let publishBudget = gaussianPublishBudgetStatePipeline.pipelineState,
              let reserveBudget = gaussianReserveBudgetSplatsPipeline.pipelineState
        else { return nil }
        return GaussianChunkCullPipelineStates(
            reset: reset,
            cull: cull,
            finalize: finalize,
            decodePreprocess: decodePreprocess,
            resetBudget: resetBudget,
            budgetScale: budgetScale,
            chunkQuotas: chunkQuotas,
            publishBudget: publishBudget,
            reserveBudget: reserveBudget
        )
    }
}

/// The view-projections one entity's chunks are tested against this frame. In a stereo frame
/// these are the two eyes: each eye's projection × the scene root's effective view of the raw
/// per-eye view `renderXR` last received (`renderInfo.xrEye0/1View`, `xrEye0/1Projection`) ×
/// the entity's model matrix. Rebuilding them here rather than reusing the composed
/// `renderInfo.xrEye0/1ViewProjection` matters: those carry the scene root of the frame that
/// drew them, while the per-splat pass this frame uses `effectiveViewMatrix` with the root
/// `updateIfNeeded` just committed — with the same root on both sides, eye 1's matrix here is
/// exactly the per-splat matrix (`cameraComponent.viewSpace` and `perspectiveSpace` hold the
/// last eye's raw view and projection), so the chunk stage still never removes a splat the
/// per-splat test keeps, even on a frame the root jumped (recentre, pinch-drag). The chunk list
/// itself is eye-agnostic — a chunk only one eye sees survives — but in Stage 1 the per-splat
/// stage that follows still filters against that single head-centre view; the either-eye rule
/// only changes the stereo image once the fused per-chunk pass replaces it. In mono, or before
/// the first stereo frame has written the eye matrices, both are the camera's projection × view
/// × model and `count` is 1.
func gaussianChunkCullViewProjections(
    modelMatrix: simd_float4x4,
    viewMatrix: simd_float4x4
) -> (first: simd_float4x4, second: simd_float4x4, count: UInt32) {
    if renderInfo.isXRStereoMode,
       renderInfo.xrEye0Projection != matrix_identity_float4x4,
       renderInfo.xrEye1Projection != matrix_identity_float4x4
    {
        let root = SceneRootTransform.shared
        let eye0 = simd_mul(renderInfo.xrEye0Projection, simd_mul(root.effectiveViewMatrix(renderInfo.xrEye0View), modelMatrix))
        let eye1 = simd_mul(renderInfo.xrEye1Projection, simd_mul(root.effectiveViewMatrix(renderInfo.xrEye1View), modelMatrix))
        return (eye0, eye1, 2)
    }
    let headViewProjection = simd_mul(renderInfo.perspectiveSpace, simd_mul(viewMatrix, modelMatrix))
    return (headViewProjection, headViewProjection, 1)
}

/// The constants of one entity's chunk cull this frame.
func gaussianChunkCullConstants(
    chunkTable: GaussianChunkTable,
    modelMatrix: simd_float4x4,
    viewMatrix: simd_float4x4,
    hzbValid: Bool,
    forceAllVisible: Bool = GaussianDebugOptions.shared.disableChunkCull
) -> GaussianChunkCullConstants {
    let views = gaussianChunkCullViewProjections(modelMatrix: modelMatrix, viewMatrix: viewMatrix)
    var constants = GaussianChunkCullConstants()
    constants.viewProjection0 = views.first
    constants.viewProjection1 = views.second
    constants.viewCount = views.count
    constants.viewport = renderInfo.viewPort ?? simd_float2(1, 1)
    constants.clipGuardBand = gaussianCullClipGuardBand
    constants.hzbOcclusionBias = gaussianCullHZBOcclusionBias
    constants.chunkCount = UInt32(chunkTable.chunkCount)
    constants.hzbValid = hzbValid ? 1 : 0
    constants.hzbReverseZ = renderInfo.reverseZEnabled ? 1 : 0
    constants.hzbMipCount = UInt32(max(0, renderInfo.hzbMipCount))
    constants.forceAllVisible = forceAllVisible ? 1 : 0
    return constants
}

/// Encodes one entity's chunk cull for one in-flight slot on an open compute encoder: reset the
/// record, one thread per chunk, finalize into indirect arguments and add the entity's visible
/// splat total to `budgetState`'s request. Serial on the encoder, so the quota and fused
/// dispatches that follow see the final list. Returns the dispatch count.
func encodeGaussianChunkCull(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer,
    constants: GaussianChunkCullConstants,
    hzbTexture: MTLTexture?
) -> Int {
    var constants = constants

    encoder.setComputePipelineState(pipelines.reset)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))

    encoder.setComputePipelineState(pipelines.cull)
    encoder.setBuffer(chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullChunkTableIndex.rawValue))
    encoder.setBytes(&constants, length: MemoryLayout<GaussianChunkCullConstants>.stride, index: Int(gaussianChunkCullConstantsIndex.rawValue))
    encoder.setBuffer(visibleChunks, offset: 0, index: Int(gaussianChunkCullVisibleChunksIndex.rawValue))
    // The record's two counters: visibleCount (splat total) at offset 0, threadgroupCount
    // (visible chunks) at offset 4 — see GaussianVisibleSet.
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianChunkCullSplatTotalIndex.rawValue))
    encoder.setBuffer(chunkSet, offset: MemoryLayout<UInt32>.stride, index: Int(gaussianChunkCullChunkTotalIndex.rawValue))
    encoder.setTexture(hzbTexture, index: Int(gaussianChunkCullHZBDepthPyramidTextureIndex.rawValue))
    let tew = pipelines.cull.threadExecutionWidth
    let block = max(min(256, pipelines.cull.maxTotalThreadsPerThreadgroup) / tew * tew, tew)
    encoder.dispatchThreadgroups(
        MTLSizeMake((chunkTable.chunkCount + block - 1) / block, 1, 1),
        threadsPerThreadgroup: MTLSizeMake(block, 1, 1)
    )

    encoder.setComputePipelineState(pipelines.finalize)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianChunkCullBudgetStateIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))

    return 3
}

/// Encodes an empty visible-chunk record for one entity — reset and finalize, no cull — so a
/// hidden entity (opacityScale 0) lists no chunk, asks nothing of the budget and dispatches no
/// threadgroup of the fused pass. Returns the dispatch count.
func encodeGaussianEmptyChunkSet(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer
) -> Int {
    encoder.setComputePipelineState(pipelines.reset)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    encoder.setComputePipelineState(pipelines.finalize)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianChunkCullBudgetStateIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    return 2
}

// MARK: - Budget and quotas

/// The scale kernel's inputs for a frame whose shared set holds `budget` records.
/// `resetHysteresis` makes the frame take its target as a first frame would.
func gaussianBudgetScaleConstants(
    budget: Int,
    forceUnitScale: Bool = GaussianDebugOptions.shared.disableWorkingSetBudget,
    resetHysteresis: Bool = false
) -> GaussianBudgetScaleConstants {
    var constants = GaussianBudgetScaleConstants()
    constants.budget = UInt32(max(0, min(budget, Int(UInt32.max))))
    constants.forceUnitScale = forceUnitScale ? 1 : 0
    constants.headroom = gaussianBudgetHeadroom
    constants.maxStepFraction = gaussianBudgetMaxStepFraction
    constants.minStep = gaussianBudgetMinStep
    constants.resetHysteresis = resetHysteresis ? 1 : 0
    return constants
}

/// Zeroes the frame's request, reservation and grant counters, before any entity's cull. One dispatch.
func encodeGaussianBudgetReset(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, budgetState: MTLBuffer) {
    encoder.setComputePipelineState(pipelines.resetBudget)
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

/// Reserves one whole-buffer entity's visible count out of the frame's budget, after its
/// `gaussianFinalizeVisibleSet` on the same encoder and before the scale dispatch. One dispatch.
func encodeGaussianBudgetReserve(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, visibleSet: MTLBuffer, budgetState: MTLBuffer) {
    encoder.setComputePipelineState(pipelines.reserveBudget)
    encoder.setBuffer(visibleSet, offset: 0, index: Int(gaussianBudgetChunkSetIndex.rawValue))
    // reservedSplats is the state's seventh word — see GaussianBudgetState.
    encoder.setBuffer(budgetState, offset: 6 * MemoryLayout<UInt32>.stride, index: Int(gaussianBudgetReservedTotalIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

/// Turns the frame's request into its scale, after every entity's chunk cull. One dispatch.
func encodeGaussianBudgetScale(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, budgetState: MTLBuffer, constants: GaussianBudgetScaleConstants) {
    var constants = constants
    encoder.setComputePipelineState(pipelines.budgetScale)
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    encoder.setBytes(&constants, length: MemoryLayout<GaussianBudgetScaleConstants>.stride, index: Int(gaussianBudgetScaleConstantsIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

/// Grants one entity's visible chunks their quotas at the frame's scale, after the scale
/// dispatch: one threadgroup striding over the visible-chunk list. One dispatch.
func encodeGaussianChunkQuotas(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer
) {
    encoder.setComputePipelineState(pipelines.chunkQuotas)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianBudgetChunkSetIndex.rawValue))
    encoder.setBuffer(visibleChunks, offset: 0, index: Int(gaussianBudgetVisibleChunksIndex.rawValue))
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    // quotaSplats is the state's second word — see GaussianBudgetState.
    encoder.setBuffer(budgetState, offset: MemoryLayout<UInt32>.stride, index: Int(gaussianBudgetQuotaTotalIndex.rawValue))
    let tew = pipelines.chunkQuotas.threadExecutionWidth
    let threads = max(min(chunkTable.chunkCount, pipelines.chunkQuotas.maxTotalThreadsPerThreadgroup) / tew * tew, tew)
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(threads, 1, 1))
}

/// Copies the frame's final budget state into `readback` for the CPU. One dispatch.
func encodeGaussianBudgetPublish(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, budgetState: MTLBuffer, readback: MTLBuffer) {
    encoder.setComputePipelineState(pipelines.publishBudget)
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    encoder.setBuffer(readback, offset: 0, index: Int(gaussianBudgetReadbackIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

// MARK: - Fused decode and preprocess

/// The per-entity inputs of `gaussianChunkDecodePreprocess` beyond the shared working set.
struct GaussianChunkPreprocessInputs {
    var packedSplats: MTLBuffer
    var chunkTable: GaussianChunkTable
    var visibleChunks: MTLBuffer
    var uniforms: Uniforms
    var cullConstants: GaussianChunkCullConstants
    var viewport: simd_float2
    var sphericalHarmonics: MTLBuffer?
    var shMetadata: GaussianSHMetadata
    var localCameraPosition: simd_float3
    var entityConstants: GaussianPreprocessEntityConstants
    var hzbTexture: MTLTexture?
}

/// Threads per threadgroup of the fused pass: one threadgroup covers one chunk, striding when
/// the chunk holds more splats than the pipeline allows per group.
func gaussianChunkPreprocessThreadsPerThreadgroup(chunkTable: GaussianChunkTable, pipelineState: MTLComputePipelineState) -> Int {
    max(1, min(chunkTable.splatsPerChunk, pipelineState.maxTotalThreadsPerThreadgroup))
}

/// Binds the fused pass for one entity and dispatches it: one threadgroup per visible chunk,
/// indirect from `chunkSet`'s dispatch arguments, or `threadgroups` direct dispatches when a
/// test drives it by hand. `threadsPerThreadgroup` defaults to the chunk width.
func encodeGaussianChunkDecodePreprocess(
    _ encoder: MTLComputeCommandEncoder,
    pipelineState: MTLComputePipelineState,
    inputs: GaussianChunkPreprocessInputs,
    chunkSet: MTLBuffer,
    sharedRecords: MTLBuffer,
    sharedKeys: MTLBuffer,
    sharedVisibleSet: MTLBuffer,
    threadsPerThreadgroup: Int? = nil,
    threadgroups: Int? = nil
) {
    var inputs = inputs
    encoder.setComputePipelineState(pipelineState)
    encoder.setBuffer(inputs.packedSplats, offset: 0, index: Int(gaussianChunkPreprocessPackedIndex.rawValue))
    encoder.setBuffer(inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessChunkTableIndex.rawValue))
    encoder.setBuffer(inputs.visibleChunks, offset: 0, index: Int(gaussianChunkPreprocessVisibleChunksIndex.rawValue))
    encoder.setBytes(&inputs.uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(gaussianChunkPreprocessUniformIndex.rawValue))
    encoder.setBytes(&inputs.cullConstants, length: MemoryLayout<GaussianChunkCullConstants>.stride, index: Int(gaussianChunkPreprocessCullConstantsIndex.rawValue))
    encoder.setBytes(&inputs.viewport, length: MemoryLayout<simd_float2>.stride, index: Int(gaussianChunkPreprocessViewportIndex.rawValue))
    // Without harmonics the metadata's degree is 0 and the kernel never reads the buffer.
    encoder.setBuffer(inputs.sphericalHarmonics ?? inputs.packedSplats, offset: 0, index: Int(gaussianChunkPreprocessSHIndex.rawValue))
    encoder.setBytes(&inputs.shMetadata, length: MemoryLayout<GaussianSHMetadata>.stride, index: Int(gaussianChunkPreprocessSHMetadataIndex.rawValue))
    encoder.setBytes(&inputs.localCameraPosition, length: MemoryLayout<simd_float3>.stride, index: Int(gaussianChunkPreprocessLocalCameraIndex.rawValue))
    encoder.setBytes(&inputs.entityConstants, length: MemoryLayout<GaussianPreprocessEntityConstants>.stride, index: Int(gaussianChunkPreprocessEntityConstantsIndex.rawValue))
    encoder.setBuffer(sharedRecords, offset: 0, index: Int(gaussianChunkPreprocessWorkingSetIndex.rawValue))
    encoder.setBuffer(sharedKeys, offset: 0, index: Int(gaussianChunkPreprocessSharedKeysIndex.rawValue))
    encoder.setBuffer(sharedVisibleSet, offset: 0, index: Int(gaussianChunkPreprocessSharedVisibleSetIndex.rawValue))
    encoder.setTexture(inputs.hzbTexture, index: Int(gaussianChunkPreprocessHZBDepthPyramidTextureIndex.rawValue))

    let threads = threadsPerThreadgroup ?? gaussianChunkPreprocessThreadsPerThreadgroup(chunkTable: inputs.chunkTable, pipelineState: pipelineState)
    if let threadgroups {
        encoder.dispatchThreadgroups(MTLSizeMake(threadgroups, 1, 1), threadsPerThreadgroup: MTLSizeMake(threads, 1, 1))
    } else {
        encoder.dispatchThreadgroups(
            indirectBuffer: chunkSet,
            indirectBufferOffset: Int(gaussianVisibleSetDispatchArgumentsOffset),
            threadsPerThreadgroup: MTLSizeMake(threads, 1, 1)
        )
    }
}
