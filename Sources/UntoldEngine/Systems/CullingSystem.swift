//
//  CullingSystem.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
import Metal
import simd

var useOptimizedCulling = false

let kInFlight = 3
let planeCount = 6
let planeStride = MemoryLayout<simd_float4>.stride

struct Plane {
    var n: simd_float3
    var d: Float // plane: n·x + d = 0
}

struct Frustum {
    var planes: [Plane] // L, R, B, T, N, F
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

// ---------- Local OBB → world AABB (handles rotation+scale safely) ----------
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

    // world halfExtent = |R| * le  (abs per element handles rotation + non-uniform scale)
    let AR = simd_float3x3(rows: [
        simd_float3(abs(R[0, 0]), abs(R[0, 1]), abs(R[0, 2])),
        simd_float3(abs(R[1, 0]), abs(R[1, 1]), abs(R[1, 2])),
        simd_float3(abs(R[2, 0]), abs(R[2, 1]), abs(R[2, 2])),
    ])
    let we = AR * le

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
    let absC0 = simd_float3(abs(R.columns.0.x), abs(R.columns.0.y), abs(R.columns.0.z))
    let absC1 = simd_float3(abs(R.columns.1.x), abs(R.columns.1.y), abs(R.columns.1.z))
    let absC2 = simd_float3(abs(R.columns.2.x), abs(R.columns.2.y), abs(R.columns.2.z))
    let worldExtent = simd_float3(
        simd_dot(absC0, localHalfExtent), // row0 of |R|
        simd_dot(absC1, localHalfExtent), // row1 of |R|
        simd_dot(absC2, localHalfExtent) // row2 of |R|
    )
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

    // clear up visible entity array
    visibleEntityIds.removeAll(keepingCapacity: true)
}

public func buildHZBDepthPyramid(_ commandBuffer: MTLCommandBuffer) {
    if hzbBuildPyramidPipeline.success == false {
        handleError(.pipelineStateNulled, hzbBuildPyramidPipeline.name ?? "HZB Build Pyramid")
        renderInfo.hzbIsValid = false
        textureResources.hzbDebugMipTexture = nil
        HZBDebugMonitor.shared.recordBuild(valid: false, mipCount: renderInfo.hzbMipCount, selectedMipLevel: max(0, renderInfo.hzbDebugMipLevel), selectedMipSize: .zero)
        return
    }

    guard let depthTexture = textureResources.depthMap else {
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

        let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.label = "HZB Build Mip \(level)"
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBytes(&mipLevel, length: MemoryLayout<UInt32>.stride, index: Int(hzbBuildPassMipLevelIndex.rawValue))
        computeEncoder.setBytes(&sourceDimensions, length: MemoryLayout<simd_uint2>.stride, index: Int(hzbBuildPassSourceDimensionsIndex.rawValue))
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
    outputVisibleCountBuffer: MTLBuffer
) -> Bool {
    if renderInfo.hzbIsValid == false {
        return false
    }

    guard let hzbDepthPyramid = textureResources.hzbDepthPyramid else {
        renderInfo.hzbIsValid = false
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
    var viewProjectionMatrix = viewProjection

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

    let viewProjection: simd_float4x4 = simd_mul(renderInfo.perspectiveSpace, cameraComponent.viewSpace)

    // build the frustum
    var frustum = buildFrustum(from: viewProjection)
    frustum = padFrustum(frustum, sidePad: 3.0)

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

        // get object AABB
        let entityAABB: EntityAABB = makeObjectAABB(localMin: localTransformComponent.boundingBox.min, localMax: localTransformComponent.boundingBox.max, worldMatrix: worldTransformComponent.space, index: getEntityIndex(entityId), version: getEntityVersion(entityId))

        entityAABBContainer.append(entityAABB)
    }

    let count = entityAABBContainer.count

    // ensure we have enough capacity
    entityAABBTripleBuffer.ensureCapacity(count)
    hzbCandidateVisibilityTriple.ensureCapacity(count)
    visibilityTriple.ensureCapacity(count)

    guard count > 0 else {
        HZBDebugMonitor.shared.recordCull(candidateCount: 0, visibleCount: 0, usedHZB: false, optimizedPath: false)
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
            candidateCount: candidateCount,
            visibleCount: Int(visibleCount),
            usedHZB: didRunOcclusion,
            optimizedPath: false
        )

        var nextVisibleIds: [EntityID] = []
        nextVisibleIds.reserveCapacity(Int(visibleCount))
        for i in 0 ..< Int(visibleCount) {
            let index = visibleEntities[i].index
            let version = visibleEntities[i].version
            nextVisibleIds.append(createEntityId(EntityIndex(index), EntityVersion(version)))
        }

        // Swap into the write slot on the render thread
        DispatchQueue.main.async {
            tripleVisibleEntities.setWrite(frame: submitFrameIndex, with: nextVisibleIds)
            cullFrameIndex = max(cullFrameIndex, submitFrameIndex + 1)
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

    let viewProjection: simd_float4x4 = simd_mul(renderInfo.perspectiveSpace, cameraComponent.viewSpace)

    // build the frustum
    var frustum = buildFrustum(from: viewProjection)
    frustum = padFrustum(frustum, sidePad: 3.0)

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

        // get object AABB
        let entityAABB: EntityAABB = makeObjectAABB(localMin: localTransformComponent.boundingBox.min, localMax: localTransformComponent.boundingBox.max, worldMatrix: worldTransformComponent.space, index: getEntityIndex(entityId), version: getEntityVersion(entityId))

        entityAABBContainer.append(entityAABB)
    }

    let count = entityAABBContainer.count

    // ensure we have enough capacity
    entityAABBTripleBuffer.ensureCapacity(count)
    hzbCandidateVisibilityTriple.ensureCapacity(count)
    visibilityTriple.ensureCapacity(count)

    guard count > 0 else {
        HZBDebugMonitor.shared.recordCull(candidateCount: 0, visibleCount: 0, usedHZB: false, optimizedPath: true)
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
            candidateCount: candidateCount,
            visibleCount: Int(visibleCount),
            usedHZB: didRunOcclusion,
            optimizedPath: true
        )

        var nextVisibleIds: [EntityID] = []
        nextVisibleIds.reserveCapacity(Int(visibleCount))
        for i in 0 ..< Int(visibleCount) {
            let index = visibleEntities[i].index
            let version = visibleEntities[i].version
            nextVisibleIds.append(createEntityId(EntityIndex(index), EntityVersion(version)))
        }

        // Swap into the write slot on the render thread
        DispatchQueue.main.async {
            tripleVisibleEntities.setWrite(frame: submitFrameIndex, with: nextVisibleIds)
            cullFrameIndex = max(cullFrameIndex, submitFrameIndex + 1)
        }
    }
}
