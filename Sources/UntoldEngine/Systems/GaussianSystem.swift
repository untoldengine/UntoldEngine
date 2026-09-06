//
//  GaussianSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  GaussianSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/10/25.
//

import CShaderTypes
import Foundation
import Metal
import simd

/// Per-entity splat cap for this platform — see GaussianRuntimeLimits.
let maxNumOfGaussians = UInt64(GaussianRuntimeLimits.maxSplatsPerEntity)

/// The CPU's view of how many splats survived the cull: read back from a *completed* frame
/// (see the completion handler in `executeGaussianFrustumCulling`), so with
/// `maxInFlightCommandBuffers` frames overlapping it lags the GPU by two or three frames.
/// Profiling and budget accounting only — no dispatch or draw is sized from it. Each pass
/// sizes itself on the GPU from this frame's `GaussianVisibleSet` instead (see
/// `dispatchOverVisibleSplats`); a set that grew since the readback would otherwise be cut
/// to the older size, dropping the tail of the visible list every frame the camera moves.
private func activeGaussianSortCount(_ component: GaussianComponent) -> Int {
    min(Int(component.visibleSplatCountForRendering), Int(component.splatCount))
}

/// Per-frame visible-set record with every splat counted as visible — the state a freshly
/// loaded entity starts in until its first cull runs, and what tests bind when they drive
/// the sort without a cull.
func makeGaussianVisibleSet(visibleCount: UInt32) -> GaussianVisibleSet {
    let block = UInt32(gaussianVisibleBlockSize)
    let threadgroups = (visibleCount + block - 1) / block
    var visibleSet = GaussianVisibleSet()
    visibleSet.visibleCount = visibleCount
    visibleSet.threadgroupCount = threadgroups
    visibleSet.threadgroupsPerGrid = (threadgroups, 1, 1)
    visibleSet.vertexCount = 4
    visibleSet.instanceCount = visibleCount
    visibleSet.vertexStart = 0
    visibleSet.baseInstance = 0
    return visibleSet
}

/// Dispatches one thread per entry of this frame's visible list, taking the threadgroup count
/// from the `GaussianVisibleSet` the cull finalised on the GPU this frame. Falls back to a
/// direct dispatch over every splat when the pipeline cannot run `gaussianVisibleBlockSize`
/// threads per threadgroup; the kernels bound-check against the same GPU count either way.
private func dispatchOverVisibleSplats(
    _ encoder: MTLComputeCommandEncoder,
    pipelineState: MTLComputePipelineState,
    visibleSet: MTLBuffer,
    splatCount: Int
) {
    let block = Int(gaussianVisibleBlockSize)
    if pipelineState.maxTotalThreadsPerThreadgroup >= block {
        encoder.dispatchThreadgroups(
            indirectBuffer: visibleSet,
            indirectBufferOffset: Int(gaussianVisibleSetDispatchArgumentsOffset),
            threadsPerThreadgroup: MTLSizeMake(block, 1, 1)
        )
    } else {
        let tew = pipelineState.threadExecutionWidth
        let fallbackBlock = max((min(pipelineState.maxTotalThreadsPerThreadgroup, block) / tew) * tew, tew)
        encoder.dispatchThreadgroups(
            MTLSizeMake((splatCount + fallbackBlock - 1) / fallbackBlock, 1, 1),
            threadsPerThreadgroup: MTLSizeMake(fallbackBlock, 1, 1)
        )
    }
}

private struct GaussianVisibleCountUpdate: @unchecked Sendable {
    let entityId: EntityID
    let component: GaussianComponent
    let visibleCount: MTLBuffer
    let splatCount: UInt
}

func initGuassianComputePipelines() {
    if renderInfo.device == nil {
        handleError(.metalDeviceNotFound)
        return
    }

    if renderInfo.library == nil {
        handleError(.metalLibraryNotFound)
        return
    }

    createComputePipeline(into: &gaussianResetVisibleCountPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianResetVisibleCount", pipelineName: "Gaussian Reset Visible Count")

    createComputePipeline(into: &gaussianFinalizeVisibleSetPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianFinalizeVisibleSet", pipelineName: "Gaussian Finalize Visible Set")

    createComputePipeline(into: &gaussianFrustumCullPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianFrustumCull", pipelineName: "Gaussian Frustum Cull")

    createComputePipeline(into: &gaussianPreprocessPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianPreprocess", pipelineName: "Gaussian Preprocess")

    createComputePipeline(into: &gaussianDepthPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianDepthKeys", pipelineName: "Gaussian Depth")

    createComputePipeline(into: &gaussianDecodePipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianDecodeChunks", pipelineName: "Gaussian Decode Chunks")

    createComputePipeline(into: &radixClearHistogramPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixClearHistogram", pipelineName: "Radix Clear")

    createComputePipeline(into: &radixHistogramPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixHistogram", pipelineName: "Radix Histogram")

    createComputePipeline(into: &radixScanPerTGPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScanPerTG", pipelineName: "Radix ScanPerTG")

    createComputePipeline(into: &radixScanPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScan", pipelineName: "Radix Scan")

    createComputePipeline(into: &radixScatterPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScatter", pipelineName: "Radix Scatter")
}

public func executeGaussianFrustumCulling(_ commandBuffer: MTLCommandBuffer) {
    let profileStart = gaussianProfilingStartTime()
    var profileTotals = GaussianProfileTotals()
    var activeSplatTotal = 0

    guard gaussianResetVisibleCountPipeline.success else {
        handleError(.pipelineStateNulled, gaussianResetVisibleCountPipeline.name!); return
    }
    guard gaussianFrustumCullPipeline.success else {
        handleError(.pipelineStateNulled, gaussianFrustumCullPipeline.name!); return
    }
    guard gaussianFinalizeVisibleSetPipeline.success else {
        handleError(.pipelineStateNulled, gaussianFinalizeVisibleSetPipeline.name!); return
    }
    guard let camera = CameraSystem.shared.activeCamera,
          let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
    else {
        handleError(.noActiveCamera)
        return
    }
    guard let resetPipelineState = gaussianResetVisibleCountPipeline.pipelineState,
          let cullPipelineState = gaussianFrustumCullPipeline.pipelineState,
          let finalizePipelineState = gaussianFinalizeVisibleSetPipeline.pipelineState
    else {
        handleError(.pipelineStateNulled, "Gaussian culling pipeline state is nil")
        return
    }

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)
    guard !entities.isEmpty else { return }

    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
    computeEncoder.label = "Gaussian Frustum Culling"

    var visibleCountUpdates: [GaussianVisibleCountUpdate] = []

    for entityId in entities {
        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noGaussianComponent, entityId)
            continue
        }
        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }
        guard !gaussianComponent.gaussianVisibleIndices.isEmpty,
              !gaussianComponent.gaussianVisibleCount.isEmpty
        else {
            handleError(.bufferAllocationFailed, "Gaussian culling buffers")
            continue
        }
        // Cull/depth-key/radix-sort write these buffers fresh every frame; slot per
        // in-flight frame (mirrors spaceUniform's indexing) so an overlapping newer frame
        // can't clobber data an older in-flight frame's draw is still reading — see the
        // comment on GaussianComponent's declaration.
        let frameSlot = min(renderInfo.currentInFlightFrameSlot, gaussianComponent.gaussianVisibleIndices.count - 1)
        guard let encodedSplatData = gaussianComponent.encodedSplatData,
              let visibleIndices = gaussianComponent.gaussianVisibleIndices[frameSlot],
              let visibleCount = gaussianComponent.gaussianVisibleCount[frameSlot]
        else {
            handleError(.bufferAllocationFailed, "Gaussian culling buffers")
            continue
        }

        profileTotals.include(component: gaussianComponent)
        activeSplatTotal += activeGaussianSortCount(gaussianComponent)

        computeEncoder.setComputePipelineState(resetPipelineState)
        computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
        computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        profileTotals.dispatchCount += 1

        let modelMatrix = simd_mul(worldTransformComponent.space, .identity)
        // Entity transforms are never modified when the scene root moves (SceneRootTransform
        // applies its offset to the camera instead, as a "virtual camera" trick — see
        // SceneRootTransform.swift). worldTransformComponent.space above is therefore in
        // entity space, so the camera side of this product must go through
        // effectiveViewMatrix, not the raw per-eye viewSpace — otherwise this cull silently
        // drifts out of sync with where the draw pass (which already uses
        // effectiveViewMatrix) actually renders the splats as soon as the scene root is
        // translated/rotated (e.g. via SpatialManipulationSystem's pinch-drag).
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        var gaussianUniform = Uniforms()
        gaussianUniform.modelViewMatrix = modelViewMatrix
        gaussianUniform.viewMatrix = viewMatrix
        gaussianUniform.modelMatrix = modelMatrix
        gaussianUniform.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace

        var totalSplats = UInt32(gaussianComponent.splatCount)
        var clipGuardBand: Float = 0.25

        // Coarse per-splat HZB occlusion pre-cull, fused into this same dispatch — see
        // the comment in gaussianFrustumCull (BitonicSort.metal). Reuses the exact same
        // temporal HZB pyramid mesh occlusion culling builds each frame
        // (buildHZBDepthPyramid); hzbIsValid guarantees hzbDepthPyramid is non-nil when
        // true, so the fallback texture below is only ever actually read when the flag
        // (and therefore the shader's own occlusion branch) is off.
        let hzbValid = renderInfo.hzbIsValid && textureResources.hzbDepthPyramid != nil
        var hzbValidFlag: UInt32 = hzbValid ? 1 : 0
        var hzbReverseZFlag: UInt32 = renderInfo.reverseZEnabled ? 1 : 0
        var hzbOcclusionBias: Float = 0.02

        computeEncoder.setComputePipelineState(cullPipelineState)
        computeEncoder.setBuffer(encodedSplatData, offset: 0, index: Int(gaussianEncodedSplatIndex.rawValue))
        computeEncoder.setBytes(&gaussianUniform, length: MemoryLayout<Uniforms>.stride, index: Int(gaussianUniformIndex.rawValue))
        computeEncoder.setBytes(&totalSplats, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))
        computeEncoder.setBuffer(visibleIndices, offset: 0, index: Int(gaussianVisibleIndicesIndex.rawValue))
        computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
        computeEncoder.setBytes(&clipGuardBand, length: MemoryLayout<Float>.stride, index: Int(gaussianIndicesIndex.rawValue))
        computeEncoder.setBytes(&hzbReverseZFlag, length: MemoryLayout<UInt32>.stride, index: Int(gaussianCullHZBReverseZIndex.rawValue))
        computeEncoder.setBytes(&hzbOcclusionBias, length: MemoryLayout<Float>.stride, index: Int(gaussianCullHZBOcclusionBiasIndex.rawValue))
        computeEncoder.setBytes(&hzbValidFlag, length: MemoryLayout<UInt32>.stride, index: Int(gaussianCullHZBValidIndex.rawValue))
        computeEncoder.setTexture(
            textureResources.hzbDepthPyramid ?? textureResources.depthMap,
            index: Int(gaussianCullHZBDepthPyramidTextureIndex.rawValue)
        )

        let tew = cullPipelineState.threadExecutionWidth
        let maxT = cullPipelineState.maxTotalThreadsPerThreadgroup
        var block = min(256, maxT)
        block = max((block / tew) * tew, tew)
        let numThreadgroups = (Int(gaussianComponent.splatCount) + block - 1) / block
        computeEncoder.dispatchThreadgroups(
            MTLSizeMake(numThreadgroups, 1, 1),
            threadsPerThreadgroup: MTLSizeMake(block, 1, 1)
        )
        profileTotals.dispatchCount += 1

        // Same serial encoder, so this runs after the cull and sees its final count: derives
        // the indirect dispatch and draw arguments the rest of this frame is sized from.
        computeEncoder.setComputePipelineState(finalizePipelineState)
        computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
        computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        profileTotals.dispatchCount += 1

        visibleCountUpdates.append(
            GaussianVisibleCountUpdate(
                entityId: entityId,
                component: gaussianComponent,
                visibleCount: visibleCount,
                splatCount: gaussianComponent.splatCount
            )
        )
    }

    computeEncoder.endEncoding()

    let updates = visibleCountUpdates
    commandBuffer.addCompletedHandler { _ in
        for update in updates {
            let count = update.visibleCount.contents().load(as: UInt32.self)
            update.component.visibleSplatCountForRendering = min(UInt(count), update.splatCount)

            // Streamed splat entities carry no RenderComponent, so they're structurally
            // excluded from the RenderComponent-keyed culling query that normally feeds
            // MemoryBudgetManager.markUsed (see CullingSystem.swift). Without this, a loaded
            // splat's lastUsedFrame would never advance and evictLRU would treat it as the
            // stalest entity in the budget regardless of actual visibility. Mark used only
            // when at least one splat survived this frame's frustum test.
            if update.component.visibleSplatCountForRendering > 0 {
                MemoryBudgetManager.shared.markUsed(entityId: update.entityId)
            }
        }
    }

    logGaussianProfile(
        stage: "FrustumCull",
        startTime: profileStart,
        totals: profileTotals,
        extra: "previousActiveSplats=\(activeSplatTotal)"
    )
}

/// Computes conic/radius/color once per visible splat per frame — previously the draw
/// vertex shader recomputed all three redundantly on each of its 4 instanced quad vertices
/// per splat (see gaussianPreprocess in Gaussians.metal). Must run after
/// executeGaussianFrustumCulling (consumes its visible-index output) and before the Gaussian
/// draw pass (which reads gaussianComponent.gaussianPrecomputedData).
public func executeGaussianPreprocess(_ commandBuffer: MTLCommandBuffer) {
    let profileStart = gaussianProfilingStartTime()
    var profileTotals = GaussianProfileTotals()
    var activeSplatTotal = 0

    guard gaussianPreprocessPipeline.success else {
        handleError(.pipelineStateNulled, gaussianPreprocessPipeline.name!); return
    }
    guard let camera = CameraSystem.shared.activeCamera,
          let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
    else {
        handleError(.noActiveCamera)
        return
    }
    guard let preprocessPipelineState = gaussianPreprocessPipeline.pipelineState else {
        handleError(.pipelineStateNulled, "Gaussian preprocess pipeline state is nil")
        return
    }

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)
    guard !entities.isEmpty else { return }

    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
    computeEncoder.label = "Gaussian Preprocess"
    computeEncoder.setComputePipelineState(preprocessPipelineState)

    for entityId in entities {
        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noGaussianComponent, entityId)
            continue
        }
        profileTotals.include(component: gaussianComponent)

        // Sized on the GPU from this frame's cull (dispatchOverVisibleSplats); the CPU count
        // is a stale readback and only feeds the profile line.
        let splatCount = Int(gaussianComponent.splatCount)
        guard splatCount > 0 else { continue }
        activeSplatTotal += activeGaussianSortCount(gaussianComponent)

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }
        // Same frame-slot indexing as executeGaussianFrustumCulling — must match, since this
        // reads that same frame's cull output and writes this same frame's precompute output.
        let frameSlot = min(renderInfo.currentInFlightFrameSlot, gaussianComponent.gaussianVisibleIndices.count - 1)
        guard let encodedSplatData = gaussianComponent.encodedSplatData,
              let visibleIndices = gaussianComponent.gaussianVisibleIndices[frameSlot],
              let visibleCount = gaussianComponent.gaussianVisibleCount[frameSlot],
              let precomputedData = gaussianComponent.gaussianPrecomputedData[frameSlot]
        else {
            handleError(.bufferAllocationFailed, "Gaussian preprocess buffers")
            continue
        }

        let modelMatrix = simd_mul(worldTransformComponent.space, .identity)

        // Same effectiveViewMatrix/effectiveCameraPosition requirement as the cull/depth
        // passes — see the comment on executeGaussianFrustumCulling.
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

        var gaussianUniform = Uniforms()
        gaussianUniform.modelViewMatrix = modelViewMatrix
        gaussianUniform.viewMatrix = viewMatrix
        gaussianUniform.modelMatrix = modelMatrix
        gaussianUniform.cameraPosition = effectiveCameraPosition
        gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace

        var localNumGaussians = UInt32(splatCount)
        var viewport = renderInfo.viewPort
        var shMetadata = gaussianComponent.sphericalHarmonicsMetadata ?? GaussianSHMetadata(
            degree: 0,
            coefficientsPerChannel: 0,
            higherOrderCoefficientsPerSplat: 0,
            _pad0: 0
        )
        var localCameraPosition = gaussianLocalCameraPosition(
            cameraWorldPosition: effectiveCameraPosition,
            modelMatrix: modelMatrix
        )

        computeEncoder.setBuffer(encodedSplatData, offset: 0, index: Int(gaussianPreprocessSplatIndex.rawValue))
        computeEncoder.setBytes(&gaussianUniform, length: MemoryLayout<Uniforms>.stride, index: Int(gaussianPreprocessUniformIndex.rawValue))
        computeEncoder.setBytes(&localNumGaussians, length: MemoryLayout<UInt32>.stride, index: Int(gaussianPreprocessNumOfSplatsIndex.rawValue))
        computeEncoder.setBuffer(visibleIndices, offset: 0, index: Int(gaussianPreprocessVisibleIndicesIndex.rawValue))
        computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianPreprocessVisibleCountIndex.rawValue))
        computeEncoder.setBytes(&viewport, length: MemoryLayout<simd_float2>.stride, index: Int(gaussianPreprocessViewportIndex.rawValue))
        computeEncoder.setBuffer(
            gaussianComponent.sphericalHarmonicsData ?? encodedSplatData,
            offset: 0,
            index: Int(gaussianPreprocessSHIndex.rawValue)
        )
        computeEncoder.setBytes(&shMetadata, length: MemoryLayout<GaussianSHMetadata>.stride, index: Int(gaussianPreprocessSHMetadataIndex.rawValue))
        computeEncoder.setBytes(&localCameraPosition, length: MemoryLayout<simd_float3>.stride, index: Int(gaussianPreprocessLocalCameraIndex.rawValue))
        computeEncoder.setBuffer(precomputedData, offset: 0, index: Int(gaussianPreprocessOutputIndex.rawValue))

        dispatchOverVisibleSplats(
            computeEncoder,
            pipelineState: preprocessPipelineState,
            visibleSet: visibleCount,
            splatCount: splatCount
        )
        profileTotals.dispatchCount += 1
    }

    computeEncoder.endEncoding()

    logGaussianProfile(
        stage: "Preprocess",
        startTime: profileStart,
        totals: profileTotals,
        extra: "activeSplats=\(activeSplatTotal)"
    )
}

public func executeGaussianDepth(_ commandBuffer: MTLCommandBuffer) {
    let profileStart = gaussianProfilingStartTime()
    var profileTotals = GaussianProfileTotals()
    var activeSplatTotal = 0

    if gaussianDepthPipeline.success == false {
        handleError(.pipelineStateNulled, gaussianDepthPipeline.name!)
        return
    }

    guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
        handleError(.noActiveCamera)
        return
    }

    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "Gaussian Depth pass"

    computeEncoder.setComputePipelineState(gaussianDepthPipeline.pipelineState!)

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

    for entityId in entities {
        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noGaussianComponent, entityId)
            continue
        }
        profileTotals.include(component: gaussianComponent)

        // Sized on the GPU from this frame's cull (dispatchOverVisibleSplats); the CPU count
        // is a stale readback and only feeds the profile line.
        let splatCount = Int(gaussianComponent.splatCount)
        guard splatCount > 0 else { continue }
        activeSplatTotal += activeGaussianSortCount(gaussianComponent)

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }

        guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else {
            handleError(.noLocalTransformComponent, entityId)
            continue
        }

        // Same frame-slot indexing as executeGaussianFrustumCulling — must match, since
        // these are the same frame's cull output being consumed here.
        guard !gaussianComponent.gaussianSortedIndices.isEmpty,
              !gaussianComponent.gaussianVisibleCount.isEmpty
        else {
            handleError(.bufferAllocationFailed, "Gaussian depth buffers")
            continue
        }
        let frameSlot = min(renderInfo.currentInFlightFrameSlot, gaussianComponent.gaussianSortedIndices.count - 1)
        guard let visibleSet = gaussianComponent.gaussianVisibleCount[min(frameSlot, gaussianComponent.gaussianVisibleCount.count - 1)] else {
            handleError(.bufferAllocationFailed, "Gaussian visible-set buffer")
            continue
        }
        computeEncoder.setBuffer(gaussianComponent.gaussianSortedIndices[frameSlot], offset: 0, index: Int(gaussianIndicesIndex.rawValue))
        computeEncoder.setBuffer(gaussianComponent.gaussianVisibleIndices[frameSlot], offset: 0, index: Int(gaussianVisibleIndicesIndex.rawValue))
        computeEncoder.setBuffer(gaussianComponent.gaussianVisibleCount[frameSlot], offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
        computeEncoder.setBuffer(
            gaussianComponent.encodedSplatData,
            offset: 0,
            index: Int(gaussianEncodedSplatIndex.rawValue)
        )

        // update uniforms
        var gaussianUniform = Uniforms()

        let modelMatrix = simd_mul(worldTransformComponent.space, .identity)

        // See the matching comment in executeGaussianFrustumCulling: worldTransformComponent
        // is in entity space, so this must be the scene-root-corrected view, not the raw
        // per-eye viewSpace.
        let viewMatrix: simd_float4x4 = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)

        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

        let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

        let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

        gaussianUniform.modelViewMatrix = modelViewMatrix

        gaussianUniform.normalMatrix = normalMatrix

        gaussianUniform.viewMatrix = viewMatrix

        gaussianUniform.modelMatrix = modelMatrix

        gaussianUniform.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

        gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace

        guard !gaussianComponent.spaceUniform.isEmpty else {
            handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
            return
        }
        let uniformBufferIndex = min(currentUniformBufferIndex(), gaussianComponent.spaceUniform.count - 1)

        if let gaussianUniformBuffer = gaussianComponent.spaceUniform[uniformBufferIndex] {
            gaussianUniformBuffer.contents().copyMemory(
                from: &gaussianUniform, byteCount: MemoryLayout<Uniforms>.stride
            )
        } else {
            handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
            return
        }

        computeEncoder.setBuffer(
            gaussianComponent.spaceUniform[uniformBufferIndex], offset: 0, index: Int(gaussianUniformIndex.rawValue)
        )

        var localNumGaussians = UInt32(splatCount)
        computeEncoder.setBytes(&localNumGaussians, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))

        dispatchOverVisibleSplats(
            computeEncoder,
            pipelineState: gaussianDepthPipeline.pipelineState!,
            visibleSet: visibleSet,
            splatCount: splatCount
        )
        profileTotals.dispatchCount += 1
    }

    computeEncoder.endEncoding()
    logGaussianProfile(
        stage: "DepthKeys",
        startTime: profileStart,
        totals: profileTotals,
        extra: "activeSplats=\(activeSplatTotal)"
    )
}

// MARK: - Device Radix Sort

//
// LSD radix sort over the upper 32 bits of the packed UInt64 key
// [depthKey | splatIndex].  Four passes of 8 bits each (bits 32-63).
//
// Per pass (all encoded into ONE MTLComputeCommandEncoder per entity):
//   0. gaussianRadixClearHistogram – zero histogram[256]          (256 threads)
//   1. gaussianRadixHistogram      – count digits + per-TG counts (N threads)
//   2. gaussianRadixScanPerTG      – exclusive scan per digit col  (256 threads)
//   3. gaussianRadixScan           – global exclusive scan         (256 threads)
//   4. gaussianRadixScatter        – stable reorder                (N threads)
//
// Using one encoder (20 dispatches, 0 blit encoders) eliminates the GPU
// pipeline stalls that come from switching encoder types 20 times per frame.
//
// Block size is fixed at 256 for both histogram and scatter so that
// histGroups == scatterGroups, which is required for correct perTGStart
// indexing (perTGStart[groupId * 256 + digit]).

public func executeRadixSort(_ commandBuffer: MTLCommandBuffer) {
    let profileStart = gaussianProfilingStartTime()
    var profileTotals = GaussianProfileTotals()
    var activeSplatTotal = 0

    guard radixClearHistogramPipeline.success else {
        handleError(.pipelineStateNulled, radixClearHistogramPipeline.name!); return
    }
    guard radixHistogramPipeline.success else {
        handleError(.pipelineStateNulled, radixHistogramPipeline.name!); return
    }
    guard radixScanPerTGPipeline.success else {
        handleError(.pipelineStateNulled, radixScanPerTGPipeline.name!); return
    }
    guard radixScanPipeline.success else {
        handleError(.pipelineStateNulled, radixScanPipeline.name!); return
    }
    guard radixScatterPipeline.success else {
        handleError(.pipelineStateNulled, radixScatterPipeline.name!); return
    }

    if radixHistogramBuffer == nil {
        radixHistogramBuffer = renderInfo.device.makeBuffer(
            length: 256 * MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
    }
    guard let histBuffer = radixHistogramBuffer else { return }

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

    // Single compute encoder for all entities and all passes.
    // Dispatches within one encoder execute sequentially on the GPU,
    // so no inter-encoder synchronisation is needed.
    guard let enc = commandBuffer.makeComputeCommandEncoder() else { return }
    enc.label = "Radix Sort"

    for entityId in entities {
        guard let gc = scene.get(component: GaussianComponent.self, for: entityId) else { continue }
        // Same frame-slot indexing as executeGaussianFrustumCulling/executeGaussianDepth —
        // sorting in place on this frame's own cull/depth-key output.
        guard !gc.gaussianSortedIndices.isEmpty, !gc.gaussianVisibleCount.isEmpty else { continue }
        let frameSlot = min(renderInfo.currentInFlightFrameSlot, gc.gaussianSortedIndices.count - 1)
        guard let sortedIndices = gc.gaussianSortedIndices[frameSlot],
              let visibleSet = gc.gaussianVisibleCount[min(frameSlot, gc.gaussianVisibleCount.count - 1)]
        else { continue }

        // `n` only sizes the scratch buffers: the kernels take this frame's element and
        // threadgroup counts from `visibleSet`, written on the GPU by the cull, and the
        // histogram/scatter dispatches are indirect from the same record.
        let n = Int(gc.splatCount)
        guard n >= 2 else { continue }
        profileTotals.include(component: gc)
        activeSplatTotal += activeGaussianSortCount(gc)

        // Ping-pong temp buffer (CPU alloc before encoding)
        let keyBufLen = n * MemoryLayout<UInt64>.stride
        if radixSortTempBuffer == nil || radixSortTempBuffer!.length < keyBufLen {
            radixSortTempBuffer = renderInfo.device.makeBuffer(
                length: keyBufLen, options: .storageModeShared
            )
        }
        guard let tempBuffer = radixSortTempBuffer else { continue }
        profileTotals.scratchBytes = max(profileTotals.scratchBytes, tempBuffer.length)

        // Fixed block size: histogram and scatter MUST use the same value so
        // that histGroups == scatterGroups and perTGStart indexing is correct — and it must
        // equal gaussianVisibleBlockSize, the block the GPU-side threadgroup count assumes.
        let radixBlock = Int(gaussianVisibleBlockSize)
        let numGroups = (n + radixBlock - 1) / radixBlock

        let perTGLen = numGroups * 256 * MemoryLayout<UInt32>.stride
        if radixPerTGHistBuffer == nil || radixPerTGHistBuffer!.length < perTGLen {
            radixPerTGHistBuffer = renderInfo.device.makeBuffer(
                length: perTGLen, options: .storageModeShared
            )
        }
        guard let perTGBuf = radixPerTGHistBuffer else { continue }
        profileTotals.scratchBytes = max(
            profileTotals.scratchBytes,
            tempBuffer.length + histBuffer.length + perTGBuf.length
        )

        var numBuckets = UInt32(256)

        for pass in 0 ..< 4 {
            let isEven = (pass % 2 == 0)
            let keysIn = isEven ? sortedIndices : tempBuffer
            let keysOut = isEven ? tempBuffer : sortedIndices
            var passIdx = UInt32(pass)

            // ── 0. Clear histogram ───────────────────────────────────────────
            enc.setComputePipelineState(radixClearHistogramPipeline.pipelineState!)
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixClearHistogramBuffer.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
            profileTotals.dispatchCount += 1

            // ── 1. Histogram + per-TG counts ─────────────────────────────────
            enc.setComputePipelineState(radixHistogramPipeline.pipelineState!)
            enc.setBuffer(keysIn, offset: 0, index: Int(radixHistogramKeysIn.rawValue))
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixHistogramOutput.rawValue))
            enc.setBuffer(perTGBuf, offset: 0, index: Int(radixHistogramPerTGOut.rawValue))
            enc.setBuffer(visibleSet, offset: 0, index: Int(radixHistogramVisibleSet.rawValue))
            enc.setBytes(&passIdx, length: MemoryLayout<UInt32>.stride, index: Int(radixHistogramPassIndex.rawValue))
            enc.dispatchThreadgroups(
                indirectBuffer: visibleSet,
                indirectBufferOffset: Int(gaussianVisibleSetDispatchArgumentsOffset),
                threadsPerThreadgroup: MTLSizeMake(radixBlock, 1, 1)
            )
            profileTotals.dispatchCount += 1

            // ── 2. Per-TG column scan → per-TG starting offsets ─────────────
            enc.setComputePipelineState(radixScanPerTGPipeline.pipelineState!)
            enc.setBuffer(perTGBuf, offset: 0, index: Int(radixScanPerTGBuffer.rawValue))
            enc.setBuffer(visibleSet, offset: 0, index: Int(radixScanPerTGVisibleSet.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
            profileTotals.dispatchCount += 1

            // ── 3. Global exclusive scan ─────────────────────────────────────
            enc.setComputePipelineState(radixScanPipeline.pipelineState!)
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixScanHistogram.rawValue))
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: Int(radixScanNumBuckets.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(256, 1, 1))
            profileTotals.dispatchCount += 1

            // ── 4. Stable scatter ────────────────────────────────────────────
            enc.setComputePipelineState(radixScatterPipeline.pipelineState!)
            enc.setBuffer(keysIn, offset: 0, index: Int(radixScatterKeysIn.rawValue))
            enc.setBuffer(keysOut, offset: 0, index: Int(radixScatterKeysOut.rawValue))
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixScatterOffsets.rawValue))
            enc.setBuffer(perTGBuf, offset: 0, index: Int(radixScatterPerTGStart.rawValue))
            enc.setBuffer(visibleSet, offset: 0, index: Int(radixScatterVisibleSet.rawValue))
            enc.setBytes(&passIdx, length: MemoryLayout<UInt32>.stride, index: Int(radixScatterPassIdx.rawValue))
            enc.dispatchThreadgroups(
                indirectBuffer: visibleSet,
                indirectBufferOffset: Int(gaussianVisibleSetDispatchArgumentsOffset),
                threadsPerThreadgroup: MTLSizeMake(radixBlock, 1, 1)
            )
            profileTotals.dispatchCount += 1
            profileTotals.radixPassCount += 1
        }
    }

    enc.endEncoding()
    logGaussianProfile(
        stage: "RadixSort",
        startTime: profileStart,
        totals: profileTotals,
        extra: "activeSplats=\(activeSplatTotal)"
    )
}
