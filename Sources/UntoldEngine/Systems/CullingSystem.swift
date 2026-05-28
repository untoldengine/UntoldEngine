//
//  CullingSystem.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
@preconcurrency import Metal
import simd

let useOptimizedCulling = true

let kInFlight = 3
let planeCount = 6
let planeStride = MemoryLayout<simd_float4>.stride

private final class VisibleSetPublishState: @unchecked Sendable {
    let lock = NSLock()
}

private let visibleSetPublishState = VisibleSetPublishState()

@inline(__always)
private func publishVisibleEntities(frame submitFrameIndex: Int, entities: [EntityID]) {
    visibleSetPublishState.lock.lock()
    tripleVisibleEntities.setWrite(frame: submitFrameIndex, with: entities)
    cullFrameIndex = max(cullFrameIndex, submitFrameIndex + 1)
    visibleSetPublishState.lock.unlock()
}

struct Plane {
    var n: simd_float3
    var d: Float // plane: n·x + d = 0
}

struct Frustum {
    var planes: [Plane] // L, R, B, T, N, F
}

@inline(__always)
private func worldAABBHalfExtent(localHalfExtent: simd_float3, linearPart R: simd_float3x3) -> simd_float3 {
    // For world-space AABB extent, use rows of |R|: e_world_i = sum_j |R_ij| * e_local_j.
    // With simd's column-major representation, `absR * e_local` evaluates that directly.
    let absR = simd_float3x3(columns: (
        simd_abs(R.columns.0),
        simd_abs(R.columns.1),
        simd_abs(R.columns.2)
    ))
    return absR * localHalfExtent
}

func padFrustum(_ F: Frustum,
                sidePad: Float = 0.5, // world units; L/R/T/B
                nearPad: Float = 0.05, // move near plane toward camera
                farPad: Float = 1.0) // move far plane farther away
    -> Frustum
{
    var p = F.planes // order: L, R, B, T, N, F
    // Assumes planes have unit-length normals
    p[0].d += sidePad // Left
    p[1].d += sidePad // Right
    p[2].d += sidePad // Bottom
    p[3].d += sidePad // Top
    p[4].d += nearPad // Near
    p[5].d += farPad // Far
    return Frustum(planes: p)
}

/// ---------- Local OBB → world AABB (handles rotation+scale safely) ----------
public func worldAABB_MinMax(localMin: simd_float3,
                             localMax: simd_float3,
                             worldMatrix M: simd_float4x4) -> (min: simd_float3, max: simd_float3)
{
    // rotation*scale (upper-left 3x3) + translation
    let R = simd_float3x3(columns: (
        simd_float3(M.columns.0.x, M.columns.0.y, M.columns.0.z),
        simd_float3(M.columns.1.x, M.columns.1.y, M.columns.1.z),
        simd_float3(M.columns.2.x, M.columns.2.y, M.columns.2.z)
    ))
    let T = simd_float3(M.columns.3.x, M.columns.3.y, M.columns.3.z)

    // local center & halfExtent
    let lc = (localMin + localMax) * 0.5
    let le = (localMax - localMin) * 0.5

    // world center
    let wc = T + R * lc

    // world halfExtent = |R|_rows * le (conservative for rotation + non-uniform scale)
    let we = worldAABBHalfExtent(localHalfExtent: le, linearPart: R)

    return (wc - we, wc + we)
}

public func worldAABB_CenterExtent(localMin: simd_float3,
                                   localMax: simd_float3,
                                   worldMatrix m: simd_float4x4) -> (center: simd_float3, halfExtent: simd_float3)
{
    // Linear part (rotation/scale/shear) and translation
    let R = simd_float3x3(columns: (
        simd_float3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
        simd_float3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
        simd_float3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
    ))
    let T = simd_float3(m.columns.3.x, m.columns.3.y, m.columns.3.z)

    // Local center & half-extent
    let localCenter = (localMin + localMax) * 0.5
    let localHalfExtent = (localMax - localMin) * 0.5

    // World center and axis-aligned half-extent (|R|·le)
    let worldCenter = T + R * localCenter
    let worldExtent = worldAABBHalfExtent(localHalfExtent: localHalfExtent, linearPart: R)
    return (worldCenter, worldExtent)
}

public func makeObjectAABB(localMin: simd_float3,
                           localMax: simd_float3,
                           worldMatrix M: simd_float4x4,
                           index: UInt32, version: UInt32) -> EntityAABB
{
    let (c, e) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: M)
    return EntityAABB(center: simd_float4(c.x, c.y, c.z, 0.0), halfExtent: simd_float4(e.x, e.y, e.z, 0.0), index: index, version: version, pad0: 0, pad1: 0)
}

/// Aspect ratio above which a world AABB is considered elongated and split into segments.
private let kSegmentAspectThreshold: Float = 3.0
/// Number of equal-length segments to split an elongated AABB into.
private let kSegmentCount: Int = 3

/// Returns one EntityAABB for compact meshes, or `kSegmentCount` AABBs along the dominant
/// axis for elongated ones.  All segments share the same (index, version) so the entity is
/// considered visible when any single segment survives culling.
func makeSegmentedEntityAABBs(localMin: simd_float3,
                              localMax: simd_float3,
                              worldMatrix M: simd_float4x4,
                              index: UInt32, version: UInt32) -> [EntityAABB]
{
    let (center, halfExtent) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: M)

    // Find the dominant (longest) half-extent axis.
    let dominantAxis: Int
    if halfExtent.x >= halfExtent.y && halfExtent.x >= halfExtent.z {
        dominantAxis = 0
    } else if halfExtent.y >= halfExtent.z {
        dominantAxis = 1
    } else {
        dominantAxis = 2
    }

    let dominantHalf = halfExtent[dominantAxis]
    let shortA: Float = dominantAxis == 0 ? halfExtent.y : halfExtent.x
    let shortB: Float = dominantAxis == 2 ? halfExtent.y : halfExtent.z
    let minShort = max(max(shortA, shortB), 1e-4)

    guard (dominantHalf / minShort) > kSegmentAspectThreshold else {
        // Not elongated – emit a single AABB.
        return [EntityAABB(
            center: simd_float4(center.x, center.y, center.z, 0),
            halfExtent: simd_float4(halfExtent.x, halfExtent.y, halfExtent.z, 0),
            index: index, version: version, pad0: 0, pad1: 0
        )]
    }

    // Split into kSegmentCount equal segments along the dominant axis.
    var result: [EntityAABB] = []
    result.reserveCapacity(kSegmentCount)
    let segHalfLen = dominantHalf / Float(kSegmentCount)
    let startOffset = -dominantHalf + segHalfLen // offset of first segment centre from entity centre

    for s in 0 ..< kSegmentCount {
        var segCenter = center
        segCenter[dominantAxis] += startOffset + Float(s) * 2.0 * segHalfLen
        var segHalf = halfExtent
        segHalf[dominantAxis] = segHalfLen

        result.append(EntityAABB(
            center: simd_float4(segCenter.x, segCenter.y, segCenter.z, 0),
            halfExtent: simd_float4(segHalf.x, segHalf.y, segHalf.z, 0),
            index: index, version: version, pad0: 0, pad1: 0
        ))
    }
    return result
}

public func performFrustumCulling(commandBuffer: MTLCommandBuffer) {
    if useOptimizedCulling {
        executeReduceScanFrustumCulling(commandBuffer)
    } else {
        executeFrustumCulling(commandBuffer)
    }
}

public func getHZBDebugStats() -> HZBDebugStats {
    HZBDebugMonitor.shared.stats
}

public func setHZBDebugLogging(enabled: Bool) {
    HZBDebugMonitor.shared.enableLogging = enabled
}

public func setHZBDebugMipLevel(_ mipLevel: Int) {
    renderInfo.hzbDebugMipLevel = max(0, mipLevel)
}

func buildFrustum(from viewProj: simd_float4x4,
                  ndcNear: Float = 0, ndcFar: Float = 1) -> Frustum
{
    let inv = simd_inverse(viewProj)

    @inline(__always)
    func unproject(_ ndc: simd_float3) -> simd_float3 {
        let p = inv * simd_float4(ndc, 1)
        return simd_float3(p.x, p.y, p.z) / p.w
    }

    // NDC corners (Metal/D3D: z in [0,1])
    let ntl = unproject([-1, +1, ndcNear])
    let ntr = unproject([+1, +1, ndcNear])
    let nbl = unproject([-1, -1, ndcNear])
    let nbr = unproject([+1, -1, ndcNear])

    let ftl = unproject([-1, +1, ndcFar])
    let ftr = unproject([+1, +1, ndcFar])
    let fbl = unproject([-1, -1, ndcFar])
    let fbr = unproject([+1, -1, ndcFar])

    @inline(__always)
    func plane(_ a: simd_float3, _ b: simd_float3, _ c: simd_float3) -> Plane {
        let n = simd_normalize(simd_cross(b - a, c - a)) // CCW seen from inside
        return Plane(n: n, d: -simd_dot(n, a))
    }

    // Planes with inward-facing CCW triplets
    var planes = [
        plane(ntl, nbl, fbl), // Left
        plane(nbr, ntr, fbr), // Right
        plane(nbl, nbr, fbr), // Bottom
        plane(ntr, ntl, ftr), // Top
        plane(ntl, ntr, nbr), // Near
        plane(ftr, ftl, fbl), // Far
    ]

    // Compute frustum center without a giant expression (avoids type-check blowup)
    let nearCenter = (ntl + ntr + nbl + nbr) * 0.25
    let farCenter = (ftl + ftr + fbl + fbr) * 0.25
    let center = (nearCenter + farCenter) * 0.5

    // Ensure normals point inward (robust orientation)
    for i in planes.indices {
        if simd_dot(planes[i].n, center) + planes[i].d < 0 {
            planes[i].n = -planes[i].n
            planes[i].d = -planes[i].d
        }
    }

    return Frustum(planes: planes)
}

func initFrustumCulllingCompute() {
    let numBlocks = (Int32(MAX_ENTITIES) + BLOCK_SIZE - 1) / BLOCK_SIZE

    if renderInfo.device == nil {
        handleError(.metalDeviceNotFound)
        return
    }

    if renderInfo.library == nil {
        handleError(.metalLibraryNotFound)
        return
    }

    // Create Pipelines
    createComputePipeline(
        into: &frustumCullingPipeline,
        device: renderInfo.device,
        library: renderInfo.library,
        functionName: "cullFrustumAABB",
        pipelineName: "Frustum Culling pipe"
    )

    createComputePipeline(into: &reduceScanMarkVisiblePipeline, device: renderInfo.device, library: renderInfo.library, functionName: "markVisibleAABB", pipelineName: "Mark Visible")

    createComputePipeline(into: &reduceScanLocalScanPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "scanLocalExclusive", pipelineName: "Reduce Scan Local")

    createComputePipeline(into: &reduceScanBlockScanPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "scanBlockSumsExclusive", pipelineName: "Reduce Scan Block")

    createComputePipeline(into: &reduceScanScatterCompactedPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "scatterCompacted", pipelineName: "Stream and compact")

    createComputePipeline(
        into: &hzbBuildPyramidPipeline,
        device: renderInfo.device,
        library: renderInfo.library,
        functionName: "hzbBuildDepthPyramid",
        pipelineName: "HZB Build Pyramid"
    )

    createComputePipeline(
        into: &hzbOcclusionCullingPipeline,
        device: renderInfo.device,
        library: renderInfo.library,
        functionName: "hzbCullVisibleEntities",
        pipelineName: "HZB Occlusion Culling"
    )

    // Make and allocate buffers
    tripleBufferResources.frustumPlane = TripleBuffer<simd_float4>(device: renderInfo.device, initialCapacity: planeCount)

    tripleBufferResources.entityAABB = TripleBuffer(device: renderInfo.device, initialCapacity: MAX_ENTITIES)

    // Per-frame visibility outputs (triple-buffered)
    tripleBufferResources.visibleCount = TripleBuffer<UInt32>(device: renderInfo.device, initialCapacity: 1)
    tripleBufferResources.visibility = TripleBuffer<VisibleEntity>(device: renderInfo.device, initialCapacity: MAX_ENTITIES)
    tripleBufferResources.hzbCandidateVisibleCount = TripleBuffer<UInt32>(device: renderInfo.device, initialCapacity: 1)
    tripleBufferResources.hzbCandidateVisibility = TripleBuffer<VisibleEntity>(device: renderInfo.device, initialCapacity: MAX_ENTITIES)

    // Reduce scan buffers
    bufferResources.reduceScanFlags = renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride * MAX_ENTITIES, options: .storageModePrivate)

    bufferResources.reduceScanIndices = renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride * MAX_ENTITIES, options: .storageModePrivate)

    bufferResources.reduceScanBlockSums = renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride * Int(numBlocks), options: .storageModePrivate)

    bufferResources.reduceScanBlockOffsets = renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride * Int(numBlocks), options: .storageModePrivate)

    // Per-eye HZB culling buffers for XR stereo (Vision Pro)
    if renderInfo.isXRStereoMode {
        tripleBufferResources.hzbEye0VisibleCount = TripleBuffer<UInt32>(device: renderInfo.device, initialCapacity: 1)
        tripleBufferResources.hzbEye0Visibility = TripleBuffer<VisibleEntity>(device: renderInfo.device, initialCapacity: MAX_ENTITIES)
        tripleBufferResources.hzbEye1VisibleCount = TripleBuffer<UInt32>(device: renderInfo.device, initialCapacity: 1)
        tripleBufferResources.hzbEye1Visibility = TripleBuffer<VisibleEntity>(device: renderInfo.device, initialCapacity: MAX_ENTITIES)
    }

    // clear up visible entity array
    visibleEntityIds.removeAll(keepingCapacity: true)
}

public func buildHZBDepthPyramid(_ commandBuffer: MTLCommandBuffer, eyeIndex: Int? = nil) {
    // Per-eye stereo path for XR
    // Current XR stereo rendering builds the shared mono HZB once after both eyes
    // are rendered, so mixed-mode opaque-depth snapshotting is handled by the
    // mono path below. If this per-eye path is wired up for mixed mode later, it
    // needs matching per-eye opaque depth snapshots to avoid glass depth culling
    // virtual meshes behind transparent surfaces.
    if let ei = eyeIndex, renderInfo.isXRStereoMode {
        guard hzbBuildPyramidPipeline.success,
              let pipelineState = hzbBuildPyramidPipeline.pipelineState,
              let depthTexture = textureResources.depthMapEye[ei],
              !textureResources.hzbMipViewsEye[ei].isEmpty
        else { return }

        let mipViews = textureResources.hzbMipViewsEye[ei]
        for level in 0 ..< mipViews.count {
            let destMip = mipViews[level]
            let sourceMip: MTLTexture? = (level > 0) ? mipViews[level - 1] : nil
            let sourceWidth = level == 0 ? depthTexture.width : (sourceMip?.width ?? 1)
            let sourceHeight = level == 0 ? depthTexture.height : (sourceMip?.height ?? 1)
            var mipLevel = UInt32(level)
            var sourceDimensions = simd_uint2(UInt32(sourceWidth), UInt32(sourceHeight))
            var reverseZFlag: UInt32 = renderInfo.reverseZEnabled ? 1 : 0
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
            computeEncoder.label = "HZB Build Eye\(ei) Mip \(level)"
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setBytes(&mipLevel, length: MemoryLayout<UInt32>.stride, index: Int(hzbBuildPassMipLevelIndex.rawValue))
            computeEncoder.setBytes(&sourceDimensions, length: MemoryLayout<simd_uint2>.stride, index: Int(hzbBuildPassSourceDimensionsIndex.rawValue))
            computeEncoder.setBytes(&reverseZFlag, length: MemoryLayout<UInt32>.stride, index: Int(hzbBuildPassReverseZIndex.rawValue))
            computeEncoder.setTexture(depthTexture, index: Int(hzbBuildPassDepthTextureIndex.rawValue))
            computeEncoder.setTexture(sourceMip, index: Int(hzbBuildPassSourceMipTextureIndex.rawValue))
            computeEncoder.setTexture(destMip, index: Int(hzbBuildPassDestMipTextureIndex.rawValue))
            let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (destMip.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
                height: (destMip.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
                depth: 1
            )
            computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            computeEncoder.endEncoding()
        }
        return
    }

    if hzbBuildPyramidPipeline.success == false {
        handleError(.pipelineStateNulled, hzbBuildPyramidPipeline.name ?? "HZB Build Pyramid")
        renderInfo.hzbIsValid = false
        textureResources.hzbDebugMipTexture = nil
        HZBDebugMonitor.shared.recordBuild(valid: false, mipCount: renderInfo.hzbMipCount, selectedMipLevel: max(0, renderInfo.hzbDebugMipLevel), selectedMipSize: .zero)
        return
    }

    let hzbDepthSource = textureResources.hzbSourceDepthMap ?? textureResources.depthMap

    guard let depthTexture = hzbDepthSource else {
        handleError(.textureMissing, "Depth Texture")
        renderInfo.hzbIsValid = false
        textureResources.hzbDebugMipTexture = nil
        HZBDebugMonitor.shared.recordBuild(valid: false, mipCount: renderInfo.hzbMipCount, selectedMipLevel: max(0, renderInfo.hzbDebugMipLevel), selectedMipSize: .zero)
        return
    }

    guard !textureResources.hzbMipViews.isEmpty else {
        renderInfo.hzbIsValid = false
        textureResources.hzbDebugMipTexture = nil
        HZBDebugMonitor.shared.recordBuild(valid: false, mipCount: renderInfo.hzbMipCount, selectedMipLevel: max(0, renderInfo.hzbDebugMipLevel), selectedMipSize: .zero)
        return
    }

    guard let pipelineState = hzbBuildPyramidPipeline.pipelineState else {
        handleError(.pipelineStateNulled, hzbBuildPyramidPipeline.name ?? "HZB Build Pyramid")
        renderInfo.hzbIsValid = false
        textureResources.hzbDebugMipTexture = nil
        HZBDebugMonitor.shared.recordBuild(valid: false, mipCount: renderInfo.hzbMipCount, selectedMipLevel: max(0, renderInfo.hzbDebugMipLevel), selectedMipSize: .zero)
        return
    }

    for level in 0 ..< textureResources.hzbMipViews.count {
        let destMip = textureResources.hzbMipViews[level]
        let sourceMip: MTLTexture? = (level > 0) ? textureResources.hzbMipViews[level - 1] : nil

        let sourceWidth = level == 0 ? depthTexture.width : (sourceMip?.width ?? 1)
        let sourceHeight = level == 0 ? depthTexture.height : (sourceMip?.height ?? 1)

        var mipLevel = UInt32(level)
        var sourceDimensions = simd_uint2(
            UInt32(sourceWidth),
            UInt32(sourceHeight)
        )
        var reverseZFlag: UInt32 = renderInfo.reverseZEnabled ? 1 : 0

        let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.label = "HZB Build Mip \(level)"
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBytes(&mipLevel, length: MemoryLayout<UInt32>.stride, index: Int(hzbBuildPassMipLevelIndex.rawValue))
        computeEncoder.setBytes(&sourceDimensions, length: MemoryLayout<simd_uint2>.stride, index: Int(hzbBuildPassSourceDimensionsIndex.rawValue))
        computeEncoder.setBytes(&reverseZFlag, length: MemoryLayout<UInt32>.stride, index: Int(hzbBuildPassReverseZIndex.rawValue))
        computeEncoder.setTexture(depthTexture, index: Int(hzbBuildPassDepthTextureIndex.rawValue))
        computeEncoder.setTexture(sourceMip, index: Int(hzbBuildPassSourceMipTextureIndex.rawValue))
        computeEncoder.setTexture(destMip, index: Int(hzbBuildPassDestMipTextureIndex.rawValue))

        let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (destMip.width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (destMip.height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
    }

    renderInfo.hzbIsValid = true

    let selectedMipLevel = min(max(renderInfo.hzbDebugMipLevel, 0), textureResources.hzbMipViews.count - 1)
    renderInfo.hzbDebugMipLevel = selectedMipLevel
    let selectedMipTexture = textureResources.hzbMipViews[selectedMipLevel]
    textureResources.hzbDebugMipTexture = selectedMipTexture

    HZBDebugMonitor.shared.recordBuild(
        valid: true,
        mipCount: renderInfo.hzbMipCount,
        selectedMipLevel: selectedMipLevel,
        selectedMipSize: simd_int2(Int32(selectedMipTexture.width), Int32(selectedMipTexture.height))
    )
}

@discardableResult
func executeHZBOcclusionCulling(
    _ commandBuffer: MTLCommandBuffer,
    viewProjection: simd_float4x4,
    dispatchCount: Int,
    inputVisibilityBuffer: MTLBuffer,
    inputVisibleCountBuffer: MTLBuffer,
    outputVisibilityBuffer: MTLBuffer,
    outputVisibleCountBuffer: MTLBuffer,
    hzbPyramidOverride: MTLTexture? = nil
) -> Bool {
    if hzbPyramidOverride == nil && renderInfo.hzbIsValid == false {
        return false
    }

    guard let hzbDepthPyramid = hzbPyramidOverride ?? textureResources.hzbDepthPyramid else {
        if hzbPyramidOverride == nil { renderInfo.hzbIsValid = false }
        return false
    }

    if hzbOcclusionCullingPipeline.success == false {
        return false
    }

    guard let pipelineState = hzbOcclusionCullingPipeline.pipelineState else {
        return false
    }

    // Reset output count before compacting surviving entities.
    let blit = commandBuffer.makeBlitCommandEncoder()!
    blit.fill(buffer: outputVisibleCountBuffer, range: 0 ..< MemoryLayout<UInt32>.stride, value: 0)
    blit.endEncoding()

    var viewport = simd_float2(renderInfo.viewPort.x, renderInfo.viewPort.y)
    var mipCount = UInt32(max(0, renderInfo.hzbMipCount))
    var reverseZFlag: UInt32 = renderInfo.reverseZEnabled ? 1 : 0
    var viewProjectionMatrix = viewProjection
    // HZB is temporal, so use a conservative bias to tolerate one-frame camera
    // and projection drift before declaring an object fully occluded.
    var occlusionBias: Float = 0.02

    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
    computeEncoder.label = "HZB Occlusion Culling pass"
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setBuffer(outputVisibilityBuffer, offset: 0, index: Int(hzbCullPassEntityAABBIndex.rawValue))
    computeEncoder.setBuffer(inputVisibleCountBuffer, offset: 0, index: Int(hzbCullPassEntityAABBCountIndex.rawValue))
    computeEncoder.setBuffer(inputVisibilityBuffer, offset: 0, index: Int(hzbCullPassVisibilityIndex.rawValue))
    computeEncoder.setBuffer(outputVisibleCountBuffer, offset: 0, index: Int(hzbCullPassVisibleCountIndex.rawValue))
    computeEncoder.setBytes(&viewProjectionMatrix, length: MemoryLayout<simd_float4x4>.stride, index: Int(hzbCullPassProjectionMatrixIndex.rawValue))
    computeEncoder.setBytes(&viewport, length: MemoryLayout<simd_float2>.stride, index: Int(hzbCullPassViewportIndex.rawValue))
    computeEncoder.setBytes(&mipCount, length: MemoryLayout<UInt32>.stride, index: Int(hzbCullPassMipCountIndex.rawValue))
    computeEncoder.setBytes(&reverseZFlag, length: MemoryLayout<UInt32>.stride, index: Int(hzbCullPassReverseZIndex.rawValue))
    computeEncoder.setBytes(&occlusionBias, length: MemoryLayout<Float>.stride, index: Int(hzbCullPassOcclusionBiasIndex.rawValue))
    computeEncoder.setTexture(hzbDepthPyramid, index: Int(hzbCullPassDepthPyramidTextureIndex.rawValue))

    let tew = pipelineState.threadExecutionWidth
    let maxT = pipelineState.maxTotalThreadsPerThreadgroup
    let target = 256
    var block = min(target, maxT)
    block = (block / tew) * tew
    block = max(block, tew)

    let threadgroups = max(1, (dispatchCount + block - 1) / block)
    computeEncoder.dispatchThreadgroups(
        MTLSize(width: threadgroups, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: block, height: 1, depth: 1)
    )
    computeEncoder.endEncoding()

    return true
}

public func executeFrustumCulling(_ commandBuffer: MTLCommandBuffer) {
    if frustumCullingPipeline.success == false {
        handleError(.pipelineStateNulled, frustumCullingPipeline.name!)
        return
    }

    guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
        handleError(.noActiveCamera)
        return
    }

    // Capture and advance submit index so in-flight frames don't reuse the same slot.
    let submitFrameIndex = cullSubmitIndex
    cullSubmitIndex += 1

    let effectiveViewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
    let viewProjection: simd_float4x4 = simd_mul(renderInfo.perspectiveSpace, effectiveViewMatrix)

    // Reverse-Z swaps near/far in NDC (near=1, far=0).
    let frustumNdcNear: Float = renderInfo.reverseZEnabled ? 1.0 : 0.0
    let frustumNdcFar: Float = renderInfo.reverseZEnabled ? 0.0 : 1.0
    var frustum = buildFrustum(from: viewProjection, ndcNear: frustumNdcNear, ndcFar: frustumNdcFar)
    frustum = padFrustum(frustum, sidePad: 3.0)
    currentFrameFrustum = frustum

    guard let frustumTripleBuffer = tripleBufferResources.frustumPlane else {
        handleError(.bufferAllocationFailed, "Frustum cull buffer")
        return
    }

    guard let entityAABBTripleBuffer = tripleBufferResources.entityAABB else {
        handleError(.bufferAllocationFailed, "Entity AABB buffer")
        return
    }

    guard let visibleCountTriple = tripleBufferResources.visibleCount else {
        handleError(.bufferAllocationFailed, "visible count triple buffer in frustum culling")
        return
    }

    guard let visibilityTriple = tripleBufferResources.visibility else {
        handleError(.bufferAllocationFailed, "visibility triple buffer in frustum culling")
        return
    }

    guard let hzbCandidateVisibleCountTriple = tripleBufferResources.hzbCandidateVisibleCount else {
        handleError(.bufferAllocationFailed, "HZB candidate count triple buffer in frustum culling")
        return
    }

    guard let hzbCandidateVisibilityTriple = tripleBufferResources.hzbCandidateVisibility else {
        handleError(.bufferAllocationFailed, "HZB candidate visibility triple buffer in frustum culling")
        return
    }

    let candidateVisibleCountBuffer = hzbCandidateVisibleCountTriple.bufferForWrite(frame: submitFrameIndex)

    // clear up candidate visible count buffer
    let blit = commandBuffer.makeBlitCommandEncoder()!
    blit.fill(buffer: candidateVisibleCountBuffer, range: 0 ..< MemoryLayout<UInt32>.stride, value: 0)
    blit.endEncoding()

    let frustumWriteBuffer = frustumTripleBuffer.bufferForWrite(frame: submitFrameIndex)
    let frustumWritePointer = frustumWriteBuffer.contents().bindMemory(to: simd_float4.self, capacity: planeCount)
    for i in 0 ..< planeCount {
        frustumWritePointer[i] = simd_float4(frustum.planes[i].n, frustum.planes[i].d)
    }

    let frustumReadBuffer = frustumTripleBuffer.bufferForRead(frame: submitFrameIndex)

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

    var entityAABBContainer: [EntityAABB] = []
    entityAABBContainer.reserveCapacity(entities.count) // Pre-allocate to avoid reallocation churn

    for entityId in entities {
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            continue
        }

        // Skip entities that are hidden (e.g., during bulk loading)
        if !renderComponent.isVisible {
            continue
        }

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            continue
        }

        if hasComponent(entityId: entityId, componentType: GizmoComponent.self) {
            continue
        }

        // In XR stereo mode, use a single AABB per entity.  The tighter sub-AABBs
        // produced by segmentation amplify temporal false-culling from 90 Hz head-
        // tracking drift and cause segment-level occlusion popping.  The unsegmented
        // AABB has a conservative nearDepth (closest corner of the full entity) that
        // is far less likely to fall behind a stale occluder in the HZB.
        if renderInfo.isXRStereoMode {
            let singleAABB = makeObjectAABB(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space,
                index: getEntityIndex(entityId),
                version: getEntityVersion(entityId)
            )
            entityAABBContainer.append(singleAABB)
        } else {
            // get object AABB — elongated meshes are split into segments so a solid
            // occluder covering only part of the entity cannot falsely cull the whole entity.
            let segments = makeSegmentedEntityAABBs(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space,
                index: getEntityIndex(entityId),
                version: getEntityVersion(entityId)
            )
            entityAABBContainer.append(contentsOf: segments)
        }
    }

    let count = entityAABBContainer.count

    // ensure we have enough capacity
    entityAABBTripleBuffer.ensureCapacity(count)
    hzbCandidateVisibilityTriple.ensureCapacity(count)
    visibilityTriple.ensureCapacity(count)

    guard count > 0 else {
        HZBDebugMonitor.shared.recordCull(testedCount: 0, candidateCount: 0, visibleCount: 0, usedHZB: false, optimizedPath: false)
        return
    }

    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "Frustum Culling pass"

    computeEncoder.setComputePipelineState(frustumCullingPipeline.pipelineState!)

    computeEncoder.setBuffer(frustumReadBuffer, offset: 0, index: Int(frustumCullingPassPlanesIndex.rawValue))

    // write current frame's data
    let entityAABBWriteBuffer = entityAABBTripleBuffer.bufferForWrite(frame: submitFrameIndex)

    entityAABBContainer.withUnsafeBytes { src in
        entityAABBWriteBuffer.contents().copyMemory(from: src.baseAddress!, byteCount: src.count)
    }

    // pick the buffer the gpu should read
    let entityAABBReadBuffer = entityAABBTripleBuffer.bufferForRead(frame: submitFrameIndex)

    let candidateVisibilityBuffer = hzbCandidateVisibilityTriple.bufferForWrite(frame: submitFrameIndex)

    computeEncoder.setBuffer(entityAABBReadBuffer, offset: 0, index: Int(frustumCullingPassObjectIndex.rawValue))

    var count32 = UInt32(count)
    computeEncoder.setBytes(&count32, length: MemoryLayout<UInt32>.stride, index: Int(frustumCullingPassObjectCountIndex.rawValue))

    computeEncoder.setBuffer(candidateVisibleCountBuffer, offset: 0, index: Int(frustumCullingPassVisibleCountIndex.rawValue))

    computeEncoder.setBuffer(candidateVisibilityBuffer, offset: 0, index: Int(frustumCullingPassVisibilityIndex.rawValue))

    let tew = frustumCullingPipeline.pipelineState?.threadExecutionWidth // e.g. 32/64
    let maxT = frustumCullingPipeline.pipelineState?.maxTotalThreadsPerThreadgroup // device cap
    let target = 256
    var block = min(target, maxT!)
    block = (block / tew!) * tew! // align down to multiple of tew
    block = max(block, tew!) // never below tew

    let threadsPerThreadgroup: MTLSize = MTLSizeMake(block, 1, 1)

    // Use dispatchThreadgroups for broader device compatibility (including Vision Pro)
    let numThreadgroups = (count + block - 1) / block
    let threadgroupsPerGrid: MTLSize = MTLSizeMake(numThreadgroups, 1, 1)

    computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

    computeEncoder.endEncoding()

    let finalVisibleCountBuffer = visibleCountTriple.bufferForWrite(frame: submitFrameIndex)
    let finalVisibilityBuffer = visibilityTriple.bufferForWrite(frame: submitFrameIndex)

    if renderInfo.isXRStereoMode,
       let eye0CountTriple = tripleBufferResources.hzbEye0VisibleCount,
       let eye0VisTriple = tripleBufferResources.hzbEye0Visibility,
       let eye1CountTriple = tripleBufferResources.hzbEye1VisibleCount,
       let eye1VisTriple = tripleBufferResources.hzbEye1Visibility
    {
        eye0VisTriple.ensureCapacity(count)
        eye1VisTriple.ensureCapacity(count)

        let eye0CountBuf = eye0CountTriple.bufferForWrite(frame: submitFrameIndex)
        let eye0VisBuf = eye0VisTriple.bufferForWrite(frame: submitFrameIndex)
        let eye1CountBuf = eye1CountTriple.bufferForWrite(frame: submitFrameIndex)
        let eye1VisBuf = eye1VisTriple.bufferForWrite(frame: submitFrameIndex)

        // Use the shared mono HZB pyramid for both eyes.
        // The per-eye pyramids (hzbDepthPyramidEye) are allocated but never built because
        // buildHZBDepthPyramid is called without eyeIndex in executeXRSystemPass, which
        // means only the mono pyramid (textureResources.hzbDepthPyramid) is populated each
        // frame.  Passing hzbDepthPyramidEye as an override bypasses the hzbIsValid guard
        // and runs the GPU shader against an uninitialized texture, producing no real
        // occlusion.  Omitting the override lets executeHZBOcclusionCulling fall back to
        // the mono pyramid gated by renderInfo.hzbIsValid, which is the intended behaviour
        // described in the comment above buildHZBDepthPyramid in UntoldEngineXR.swift.
        let ran0 = executeHZBOcclusionCulling(
            commandBuffer,
            viewProjection: renderInfo.xrEye0ViewProjection,
            dispatchCount: count,
            inputVisibilityBuffer: candidateVisibilityBuffer,
            inputVisibleCountBuffer: candidateVisibleCountBuffer,
            outputVisibilityBuffer: eye0VisBuf,
            outputVisibleCountBuffer: eye0CountBuf
        )

        let ran1 = executeHZBOcclusionCulling(
            commandBuffer,
            viewProjection: renderInfo.xrEye1ViewProjection,
            dispatchCount: count,
            inputVisibilityBuffer: candidateVisibilityBuffer,
            inputVisibleCountBuffer: candidateVisibleCountBuffer,
            outputVisibilityBuffer: eye1VisBuf,
            outputVisibleCountBuffer: eye1CountBuf
        )

        let didRunOcclusion = ran0 || ran1

        commandBuffer.addCompletedHandler { _ in
            var seen = Set<EntityID>()
            var nextVisibleIds: [EntityID] = []

            // Union eye0 ∪ eye1: any entity visible in either eye is kept.
            let addFrom = { (countBuf: MTLBuffer, visBuf: MTLBuffer) in
                let cnt = Int(countBuf.contents().load(as: UInt32.self))
                let ents = visBuf.contents().bindMemory(to: VisibleEntity.self, capacity: cnt)
                for i in 0 ..< cnt {
                    let eid = createEntityId(EntityIndex(ents[i].index), EntityVersion(ents[i].version))
                    if seen.insert(eid).inserted { nextVisibleIds.append(eid) }
                }
            }

            if ran0 { addFrom(eye0CountBuf, eye0VisBuf) }
            if ran1 { addFrom(eye1CountBuf, eye1VisBuf) }
            // If HZB wasn't valid yet (first frame), fall back to frustum candidates.
            if !didRunOcclusion { addFrom(candidateVisibleCountBuffer, candidateVisibilityBuffer) }

            // Read actual GPU-produced counts now that the command buffer has completed.
            let candidateCount = Int(candidateVisibleCountBuffer.contents().load(as: UInt32.self))
            HZBDebugMonitor.shared.recordCull(
                testedCount: count,
                candidateCount: candidateCount,
                visibleCount: nextVisibleIds.count,
                usedHZB: didRunOcclusion,
                optimizedPath: false
            )

            publishVisibleEntities(frame: submitFrameIndex, entities: nextVisibleIds)
        }

    } else {
        // Mono path (macOS / non-stereo)
        let didRunOcclusion = executeHZBOcclusionCulling(
            commandBuffer,
            viewProjection: viewProjection,
            dispatchCount: count,
            inputVisibilityBuffer: candidateVisibilityBuffer,
            inputVisibleCountBuffer: candidateVisibleCountBuffer,
            outputVisibilityBuffer: finalVisibilityBuffer,
            outputVisibleCountBuffer: finalVisibleCountBuffer
        )

        let resolvedVisibleCountBuffer = didRunOcclusion ? finalVisibleCountBuffer : candidateVisibleCountBuffer
        let resolvedVisibilityBuffer = didRunOcclusion ? finalVisibilityBuffer : candidateVisibilityBuffer

        commandBuffer.addCompletedHandler { _ in
            let candidateCount = Int(candidateVisibleCountBuffer.contents().load(as: UInt32.self))
            let visibleCount = resolvedVisibleCountBuffer.contents().load(as: UInt32.self)
            let visibleEntities = resolvedVisibilityBuffer.contents().bindMemory(to: VisibleEntity.self, capacity: Int(visibleCount))

            HZBDebugMonitor.shared.recordCull(
                testedCount: count,
                candidateCount: candidateCount,
                visibleCount: Int(visibleCount),
                usedHZB: didRunOcclusion,
                optimizedPath: false
            )

            // Deduplicate: elongated entities emit multiple segments that share the same
            // (index, version), so the same EntityID can appear more than once in the
            // surviving output.  Keep only the first occurrence.
            var seen = Set<EntityID>()
            let nextVisibleIds: [EntityID] = (0 ..< Int(visibleCount)).compactMap { i in
                let index = visibleEntities[i].index
                let version = visibleEntities[i].version
                let entityId = createEntityId(EntityIndex(index), EntityVersion(version))
                return seen.insert(entityId).inserted ? entityId : nil
            }

            publishVisibleEntities(frame: submitFrameIndex, entities: nextVisibleIds)
        }
    }
}

func executeReduceScanFrustumCulling(_ commandBuffer: MTLCommandBuffer) {
    if reduceScanMarkVisiblePipeline.success == false {
        handleError(.pipelineStateNulled, reduceScanMarkVisiblePipeline.name!)
        return
    }

    if reduceScanLocalScanPipeline.success == false {
        handleError(.pipelineStateNulled, reduceScanLocalScanPipeline.name!)
        return
    }

    if reduceScanBlockScanPipeline.success == false {
        handleError(.pipelineStateNulled, reduceScanBlockScanPipeline.name!)
        return
    }

    if reduceScanScatterCompactedPipeline.success == false {
        handleError(.pipelineStateNulled, reduceScanScatterCompactedPipeline.name!)
        return
    }

    guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
        handleError(.noActiveCamera)
        return
    }

    // Capture and advance submit index so in-flight frames don't reuse the same slot.
    let submitFrameIndex = cullSubmitIndex
    cullSubmitIndex += 1

    let numBlocks = (Int32(MAX_ENTITIES) + BLOCK_SIZE - 1) / BLOCK_SIZE

    let effectiveViewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
    let viewProjection: simd_float4x4 = simd_mul(renderInfo.perspectiveSpace, effectiveViewMatrix)

    // Reverse-Z swaps near/far in NDC (near=1, far=0).
    let frustumNdcNear: Float = renderInfo.reverseZEnabled ? 1.0 : 0.0
    let frustumNdcFar: Float = renderInfo.reverseZEnabled ? 0.0 : 1.0
    var frustum = buildFrustum(from: viewProjection, ndcNear: frustumNdcNear, ndcFar: frustumNdcFar)
    frustum = padFrustum(frustum, sidePad: 3.0)
    currentFrameFrustum = frustum

    guard let frustumTripleBuffer = tripleBufferResources.frustumPlane else {
        handleError(.bufferAllocationFailed, "Frustum cull buffer")
        return
    }

    guard let entityAABBTripleBuffer = tripleBufferResources.entityAABB else {
        handleError(.bufferAllocationFailed, "Entity AABB buffer")
        return
    }

    guard let visibleCountTriple = tripleBufferResources.visibleCount else {
        handleError(.bufferAllocationFailed, "visible count triple buffer in frustum culling")
        return
    }

    guard let visibilityTriple = tripleBufferResources.visibility else {
        handleError(.bufferAllocationFailed, "visibility triple buffer in frustum culling")
        return
    }

    guard let hzbCandidateVisibleCountTriple = tripleBufferResources.hzbCandidateVisibleCount else {
        handleError(.bufferAllocationFailed, "HZB candidate count triple buffer in frustum culling")
        return
    }

    guard let hzbCandidateVisibilityTriple = tripleBufferResources.hzbCandidateVisibility else {
        handleError(.bufferAllocationFailed, "HZB candidate visibility triple buffer in frustum culling")
        return
    }

    let candidateVisibleCountBuffer = hzbCandidateVisibleCountTriple.bufferForWrite(frame: submitFrameIndex)

    // clear up candidate visible count buffer
    let blit = commandBuffer.makeBlitCommandEncoder()!
    blit.fill(buffer: candidateVisibleCountBuffer, range: 0 ..< MemoryLayout<UInt32>.stride, value: 0)
    blit.endEncoding()

    let frustumWriteBuffer = frustumTripleBuffer.bufferForWrite(frame: submitFrameIndex)
    let frustumWritePointer = frustumWriteBuffer.contents().bindMemory(to: simd_float4.self, capacity: planeCount)
    for i in 0 ..< planeCount {
        frustumWritePointer[i] = simd_float4(frustum.planes[i].n, frustum.planes[i].d)
    }

    let frustumReadBuffer = frustumTripleBuffer.bufferForRead(frame: submitFrameIndex)

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

    var entityAABBContainer: [EntityAABB] = []
    entityAABBContainer.reserveCapacity(entities.count) // Pre-allocate to avoid reallocation churn

    for entityId in entities {
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            continue
        }

        // Skip entities that are hidden (e.g., during bulk loading)
        if !renderComponent.isVisible {
            continue
        }

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            continue
        }

        if hasComponent(entityId: entityId, componentType: LightComponent.self) {
            continue
        }

        // get object AABB — elongated meshes are split into segments.
        let segments = makeSegmentedEntityAABBs(
            localMin: localTransformComponent.boundingBox.min,
            localMax: localTransformComponent.boundingBox.max,
            worldMatrix: worldTransformComponent.space,
            index: getEntityIndex(entityId),
            version: getEntityVersion(entityId)
        )
        entityAABBContainer.append(contentsOf: segments)
    }

    let count = entityAABBContainer.count

    // ensure we have enough capacity
    entityAABBTripleBuffer.ensureCapacity(count)
    hzbCandidateVisibilityTriple.ensureCapacity(count)
    visibilityTriple.ensureCapacity(count)

    guard count > 0 else {
        HZBDebugMonitor.shared.recordCull(testedCount: 0, candidateCount: 0, visibleCount: 0, usedHZB: false, optimizedPath: true)
        return
    }

    // write current frame's data
    let entityAABBWriteBuffer = entityAABBTripleBuffer.bufferForWrite(frame: submitFrameIndex)

    entityAABBContainer.withUnsafeBytes { src in
        entityAABBWriteBuffer.contents().copyMemory(from: src.baseAddress!, byteCount: src.count)
    }

    // pick the buffer the gpu should read
    let entityAABBReadBuffer = entityAABBTripleBuffer.bufferForRead(frame: submitFrameIndex)

    let candidateVisibilityBuffer = hzbCandidateVisibilityTriple.bufferForWrite(frame: submitFrameIndex)

    var count32 = UInt32(count)

    // Mark visible launch
    do {
        let computeEncoderMarkVisible: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoderMarkVisible.label = "Mark Visible Pass"

        computeEncoderMarkVisible.setComputePipelineState(reduceScanMarkVisiblePipeline.pipelineState!)

        computeEncoderMarkVisible.setBuffer(frustumReadBuffer, offset: 0, index: Int(markVisibilityPassFrustumIndex.rawValue))
        computeEncoderMarkVisible.setBuffer(entityAABBReadBuffer, offset: 0, index: Int(markVisibilityPassEntityAABBIndex.rawValue))
        computeEncoderMarkVisible.setBytes(&count32, length: MemoryLayout<UInt32>.stride, index: Int(markVisibilityPassEntityAABBCountIndex.rawValue))
        computeEncoderMarkVisible.setBuffer(bufferResources.reduceScanFlags, offset: 0, index: Int(markVisibilityPassFlagIndex.rawValue))

        let w = min(reduceScanMarkVisiblePipeline.pipelineState!.maxTotalThreadsPerThreadgroup, 256)
        let numThreadgroups = (count + w - 1) / w
        computeEncoderMarkVisible.dispatchThreadgroups(MTLSize(width: numThreadgroups, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))

        computeEncoderMarkVisible.endEncoding()
    }

    // scan local
    do {
        let computeEncoderLocalScan: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoderLocalScan.label = "Local Scan Pass"

        computeEncoderLocalScan.setComputePipelineState(reduceScanLocalScanPipeline.pipelineState!)

        computeEncoderLocalScan.setBuffer(bufferResources.reduceScanFlags, offset: 0, index: Int(scanLocalPassFlagIndex.rawValue))

        computeEncoderLocalScan.setBuffer(bufferResources.reduceScanIndices, offset: 0, index: Int(scanLocalPassIndicesIndex.rawValue))

        computeEncoderLocalScan.setBuffer(bufferResources.reduceScanBlockSums, offset: 0, index: Int(scanLocalPassBlockSumsIndex.rawValue))

        computeEncoderLocalScan.setBytes(&count32, length: MemoryLayout<UInt32>.stride, index: Int(scanLocalPassCountIndex.rawValue))

        computeEncoderLocalScan.dispatchThreadgroups(MTLSize(width: Int(numBlocks), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: Int(BLOCK_SIZE), height: 1, depth: 1))

        computeEncoderLocalScan.endEncoding()
    }

    // scan block

    do {
        let computeEncoderBlockScan: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoderBlockScan.label = "Block Scan Pass"

        computeEncoderBlockScan.setComputePipelineState(reduceScanBlockScanPipeline.pipelineState!)

        computeEncoderBlockScan.setBuffer(bufferResources.reduceScanBlockSums, offset: 0, index: Int(scanBlockSumPassSumIndex.rawValue))

        computeEncoderBlockScan.setBuffer(bufferResources.reduceScanBlockOffsets, offset: 0, index: Int(scanBlockSumPassOffsetIndex.rawValue))

        var nbU32 = UInt32(numBlocks)
        computeEncoderBlockScan.setBytes(&nbU32, length: 4, index: 2)

        var threads = 1
        while threads < numBlocks {
            threads <<= 1
        }
        threads = min(1024, threads)
        computeEncoderBlockScan.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
                                                     threadsPerThreadgroup: MTLSize(width: threads, height: 1, depth: 1))
        computeEncoderBlockScan.endEncoding()
    }

    // Compact and stream
    do {
        let computeEncoderCompact: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoderCompact.label = "Compact and Stream Pass"

        computeEncoderCompact.setComputePipelineState(reduceScanScatterCompactedPipeline.pipelineState!)

        computeEncoderCompact.setBuffer(bufferResources.reduceScanFlags, offset: 0, index: Int(compactPassFlagsIndex.rawValue))
        computeEncoderCompact.setBuffer(bufferResources.reduceScanIndices, offset: 0, index: Int(compactPassIndicesIndex.rawValue))
        computeEncoderCompact.setBuffer(bufferResources.reduceScanBlockOffsets, offset: 0, index: Int(compactPassBlockOffsetIndex.rawValue))
        computeEncoderCompact.setBuffer(entityAABBReadBuffer, offset: 0, index: Int(compactPassEntityAABBIndex.rawValue))

        computeEncoderCompact.setBytes(&count32, length: MemoryLayout<UInt32>.stride, index: Int(compactPassCountIndex.rawValue))

        computeEncoderCompact.setBuffer(candidateVisibilityBuffer, offset: 0, index: Int(compactPassVisibilityIndicesIndex.rawValue))
        computeEncoderCompact.setBuffer(candidateVisibleCountBuffer, offset: 0, index: Int(compactPassVisibilityCountIndex.rawValue))

        let w = min(reduceScanScatterCompactedPipeline.pipelineState!.maxTotalThreadsPerThreadgroup, 256)
        let numThreadgroups = (Int(count32) + w - 1) / w
        computeEncoderCompact.dispatchThreadgroups(MTLSize(width: numThreadgroups, height: 1, depth: 1),
                                                   threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))

        computeEncoderCompact.endEncoding()
    }

    let finalVisibleCountBuffer = visibleCountTriple.bufferForWrite(frame: submitFrameIndex)
    let finalVisibilityBuffer = visibilityTriple.bufferForWrite(frame: submitFrameIndex)

    let didRunOcclusion = executeHZBOcclusionCulling(
        commandBuffer,
        viewProjection: viewProjection,
        dispatchCount: count,
        inputVisibilityBuffer: candidateVisibilityBuffer,
        inputVisibleCountBuffer: candidateVisibleCountBuffer,
        outputVisibilityBuffer: finalVisibilityBuffer,
        outputVisibleCountBuffer: finalVisibleCountBuffer
    )

    let resolvedVisibleCountBuffer = didRunOcclusion ? finalVisibleCountBuffer : candidateVisibleCountBuffer
    let resolvedVisibilityBuffer = didRunOcclusion ? finalVisibilityBuffer : candidateVisibilityBuffer

    commandBuffer.addCompletedHandler { _ in
        let candidateCount = Int(candidateVisibleCountBuffer.contents().load(as: UInt32.self))
        let visibleCount = resolvedVisibleCountBuffer.contents().load(as: UInt32.self)
        let visibleEntities = resolvedVisibilityBuffer.contents().bindMemory(to: VisibleEntity.self, capacity: Int(visibleCount))

        HZBDebugMonitor.shared.recordCull(
            testedCount: count,
            candidateCount: candidateCount,
            visibleCount: Int(visibleCount),
            usedHZB: didRunOcclusion,
            optimizedPath: true
        )

        // Deduplicate: elongated entities emit multiple segments sharing (index, version).
        var seen = Set<EntityID>()
        let nextVisibleIds: [EntityID] = (0 ..< Int(visibleCount)).compactMap { i in
            let index = visibleEntities[i].index
            let version = visibleEntities[i].version
            let entityId = createEntityId(EntityIndex(index), EntityVersion(version))
            return seen.insert(entityId).inserted ? entityId : nil
        }

        publishVisibleEntities(frame: submitFrameIndex, entities: nextVisibleIds)
    }
}

/// Returns true when the axis-aligned bounding box defined by `aabbMin`/`aabbMax`
/// is at least partially inside all planes of `frustum`.
///
/// Uses the positive-vertex test: for each plane we find the corner of the AABB
/// that is furthest in the direction of the plane normal (the "most positive"
/// projection).  If that corner is on the outside of any plane, the entire AABB
/// is outside the frustum and can be culled.
func isAABBInFrustum(_ frustum: Frustum, min aabbMin: simd_float3, max aabbMax: simd_float3) -> Bool {
    for plane in frustum.planes {
        let px = plane.n.x >= 0 ? aabbMax.x : aabbMin.x
        let py = plane.n.y >= 0 ? aabbMax.y : aabbMin.y
        let pz = plane.n.z >= 0 ? aabbMax.z : aabbMin.z
        if simd_dot(plane.n, simd_float3(px, py, pz)) + plane.d < 0 {
            return false
        }
    }
    return true
}

/// Overload accepting center+halfExtent form. Delegates to the min/max variant.
@inline(__always)
func isAABBInFrustum(center: simd_float3, halfExtent: simd_float3, frustum: Frustum) -> Bool {
    isAABBInFrustum(frustum, min: center - halfExtent, max: center + halfExtent)
}
