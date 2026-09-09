//
//  GaussianChunkCull.swift
//  UntoldEngine
//
//  CPU side of the chunk-level cull of .untoldgs entities (GaussianChunkCull.metal): the
//  per-slot buffers a chunked entity carries, the per-frame constants, the encode of the three
//  chunk dispatches, and a CPU mirror of the chunk test for tests and callers that want to
//  predict what the GPU keeps.
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
        GaussianVisibleChunk(chunkIndex: UInt32(index), splatCount: chunk.splatCount)
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

/// The compiled chunk-cull kernels, or nil while any of them is missing (the chunked entity then
/// takes the whole-buffer per-splat path).
struct GaussianChunkCullPipelineStates {
    let reset: MTLComputePipelineState
    let cull: MTLComputePipelineState
    let finalize: MTLComputePipelineState
    let splatCull: MTLComputePipelineState

    static func current() -> GaussianChunkCullPipelineStates? {
        guard gaussianResetVisibleChunkSetPipeline.success,
              gaussianChunkCullPipeline.success,
              gaussianFinalizeVisibleChunksPipeline.success,
              gaussianChunkSplatCullPipeline.success,
              let reset = gaussianResetVisibleChunkSetPipeline.pipelineState,
              let cull = gaussianChunkCullPipeline.pipelineState,
              let finalize = gaussianFinalizeVisibleChunksPipeline.pipelineState,
              let splatCull = gaussianChunkSplatCullPipeline.pipelineState
        else { return nil }
        return GaussianChunkCullPipelineStates(reset: reset, cull: cull, finalize: finalize, splatCull: splatCull)
    }
}

/// The view-projections one entity's chunks are tested against this frame. In a stereo frame
/// these are the previous frame's two eye matrices (`renderInfo.xrEye0/1ViewProjection`, written
/// per eye by `renderXR`) with the entity's model matrix folded in — never the single
/// head-centre matrix the per-splat passes use, because a chunk that only one eye sees has to
/// survive for that eye's draw. In mono, or before the first stereo frame has written the eye
/// matrices, both are the camera's projection × view × model and `count` is 1.
func gaussianChunkCullViewProjections(
    modelMatrix: simd_float4x4,
    viewMatrix: simd_float4x4
) -> (first: simd_float4x4, second: simd_float4x4, count: UInt32) {
    if renderInfo.isXRStereoMode,
       renderInfo.xrEye0ViewProjection != matrix_identity_float4x4,
       renderInfo.xrEye1ViewProjection != matrix_identity_float4x4
    {
        return (
            simd_mul(renderInfo.xrEye0ViewProjection, modelMatrix),
            simd_mul(renderInfo.xrEye1ViewProjection, modelMatrix),
            2
        )
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
/// record, one thread per chunk, finalize into indirect arguments. Serial on the encoder, so
/// the per-splat dispatch that follows sees the final list. Returns the dispatch count.
func encodeGaussianChunkCull(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
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
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))

    return 3
}

/// Threads per threadgroup of `gaussianChunkSplatCull`: one threadgroup covers one chunk, striding
/// when the chunk holds more splats than the pipeline allows per group.
func gaussianChunkSplatCullThreadsPerThreadgroup(chunkTable: GaussianChunkTable, pipelineState: MTLComputePipelineState) -> Int {
    max(1, min(chunkTable.splatsPerChunk, pipelineState.maxTotalThreadsPerThreadgroup))
}
