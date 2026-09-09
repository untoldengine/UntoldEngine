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
    visibleSet.overflowCount = 0
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

/// The shared visible set handed to a command buffer's completed handler: the buffer is only
/// read there, after the GPU has finished with it, so the capture is safe.
private struct GaussianSharedVisibleSetReadback: @unchecked Sendable {
    let buffer: MTLBuffer
}

private struct GaussianVisibleCountUpdate: @unchecked Sendable {
    let entityId: EntityID
    let component: GaussianComponent
    let visibleCount: MTLBuffer
    let splatCount: UInt
}

/// The whole-buffer per-splat cull's inputs (`gaussianFrustumCull`).
private struct GaussianSplatCullInputs {
    var uniforms: Uniforms
    var totalSplats: UInt32
    var clipGuardBand: Float = gaussianCullClipGuardBand
    var hzbReverseZ: UInt32
    var hzbOcclusionBias: Float = gaussianCullHZBOcclusionBias
    var hzbValid: UInt32
}

private func bindGaussianSplatCullInputs(
    _ encoder: MTLComputeCommandEncoder,
    pipelineState: MTLComputePipelineState,
    inputs: GaussianSplatCullInputs,
    encodedSplatData: MTLBuffer,
    visibleIndices: MTLBuffer,
    visibleCount: MTLBuffer,
    hzbTexture: MTLTexture?
) {
    var inputs = inputs
    encoder.setComputePipelineState(pipelineState)
    encoder.setBuffer(encodedSplatData, offset: 0, index: Int(gaussianEncodedSplatIndex.rawValue))
    encoder.setBytes(&inputs.uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(gaussianUniformIndex.rawValue))
    encoder.setBytes(&inputs.totalSplats, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))
    encoder.setBuffer(visibleIndices, offset: 0, index: Int(gaussianVisibleIndicesIndex.rawValue))
    encoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.setBytes(&inputs.clipGuardBand, length: MemoryLayout<Float>.stride, index: Int(gaussianIndicesIndex.rawValue))
    encoder.setBytes(&inputs.hzbReverseZ, length: MemoryLayout<UInt32>.stride, index: Int(gaussianCullHZBReverseZIndex.rawValue))
    encoder.setBytes(&inputs.hzbOcclusionBias, length: MemoryLayout<Float>.stride, index: Int(gaussianCullHZBOcclusionBiasIndex.rawValue))
    encoder.setBytes(&inputs.hzbValid, length: MemoryLayout<UInt32>.stride, index: Int(gaussianCullHZBValidIndex.rawValue))
    encoder.setTexture(hzbTexture, index: Int(gaussianCullHZBDepthPyramidTextureIndex.rawValue))
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

    createComputePipeline(into: &gaussianFinalizeSharedVisibleSetPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianFinalizeSharedVisibleSet", pipelineName: "Gaussian Finalize Shared Visible Set")

    createComputePipeline(into: &gaussianDecodePipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianDecodeChunks", pipelineName: "Gaussian Decode Chunks")

    createComputePipeline(into: &gaussianResetVisibleChunkSetPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianResetVisibleChunkSet", pipelineName: "Gaussian Reset Visible Chunk Set")

    createComputePipeline(into: &gaussianChunkCullPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianChunkCull", pipelineName: "Gaussian Chunk Cull")

    createComputePipeline(into: &gaussianFinalizeVisibleChunksPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianFinalizeVisibleChunks", pipelineName: "Gaussian Finalize Visible Chunks")

    createComputePipeline(into: &gaussianChunkDecodePreprocessPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianChunkDecodePreprocess", pipelineName: "Gaussian Chunk Decode Preprocess")

    createComputePipeline(into: &gaussianResetBudgetRequestPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianResetBudgetRequest", pipelineName: "Gaussian Reset Budget Request")

    createComputePipeline(into: &gaussianComputeBudgetScalePipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianComputeBudgetScale", pipelineName: "Gaussian Compute Budget Scale")

    createComputePipeline(into: &gaussianComputeChunkQuotasPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianComputeChunkQuotas", pipelineName: "Gaussian Compute Chunk Quotas")

    createComputePipeline(into: &gaussianPublishBudgetStatePipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianPublishBudgetState", pipelineName: "Gaussian Publish Budget State")

    createComputePipeline(into: &radixClearHistogramPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixClearHistogram", pipelineName: "Radix Clear")

    createComputePipeline(into: &radixHistogramPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixHistogram", pipelineName: "Radix Histogram")

    createComputePipeline(into: &radixScanPerTGPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScanPerTG", pipelineName: "Radix ScanPerTG")

    createComputePipeline(into: &radixScanPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScan", pipelineName: "Radix Scan")

    createComputePipeline(into: &radixScatterPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScatter", pipelineName: "Radix Scatter")
}

/// The previous frame's HZB as the splat culls read it: valid only when the pyramid exists and
/// the debug switch leaves it on (the fallback texture is then never sampled).
private func gaussianHZBInputs() -> (valid: Bool, texture: MTLTexture?) {
    let valid = renderInfo.hzbIsValid && textureResources.hzbDepthPyramid != nil
        && !GaussianDebugOptions.shared.disableHZBOcclusionCull
    return (valid, textureResources.hzbDepthPyramid ?? textureResources.depthMap)
}

/// The head-centre matrices of one entity this frame, shared by the cull and the preprocess.
private struct GaussianEntityFrameMatrices {
    let modelMatrix: simd_float4x4
    let viewMatrix: simd_float4x4
    let effectiveCameraPosition: simd_float3
    let uniforms: Uniforms

    init(worldTransform: WorldTransformComponent, cameraComponent: CameraComponent) {
        modelMatrix = simd_mul(worldTransform.space, .identity)
        // Entity transforms are never modified when the scene root moves (SceneRootTransform
        // applies its offset to the camera instead, as a "virtual camera" trick — see
        // SceneRootTransform.swift). worldTransform.space above is therefore in entity space,
        // so the camera side of this product must go through effectiveViewMatrix, not the raw
        // per-eye viewSpace — otherwise the cull silently drifts out of sync with where the
        // draw pass (which already uses effectiveViewMatrix) actually renders the splats as
        // soon as the scene root is translated/rotated (e.g. via SpatialManipulationSystem's
        // pinch-drag).
        viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        var gaussianUniform = Uniforms()
        gaussianUniform.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        gaussianUniform.viewMatrix = viewMatrix
        gaussianUniform.modelMatrix = modelMatrix
        gaussianUniform.cameraPosition = effectiveCameraPosition
        gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace
        uniforms = gaussianUniform
    }
}

/// A chunked entity whose chunk cull ran this frame and whose quotas are still to be granted.
private struct GaussianChunkedEntityFrame {
    let chunkTable: GaussianChunkTable
    let visibleChunks: MTLBuffer
    let chunkSet: MTLBuffer
}

/// The working-set budget of this frame in splats: the resident total with the debug switch on
/// (nothing is ever truncated), otherwise `GaussianSharedWorkingSet.budgetSplats()`.
func gaussianWorkingSetBudget(residentSplats: Int) -> Int {
    GaussianDebugOptions.shared.disableWorkingSetBudget ? max(1, residentSplats) : GaussianSharedWorkingSet.budgetSplats()
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

    // The frame's shared working set: sized to the budget (never above the resident total, which
    // no frame can exceed). Chunked entities are fitted to it through per-chunk quotas below;
    // whole-buffer entities append whatever their cull keeps, the finalize clamp catching any
    // excess.
    let residentSplats = entities.reduce(0) { total, entityId in
        total + Int(scene.get(component: GaussianComponent.self, for: entityId)?.splatCount ?? 0)
    }
    let workingSet = GaussianSharedWorkingSet.shared
    let budget = gaussianWorkingSetBudget(residentSplats: residentSplats)
    guard let capacity = workingSet.fitCapacity(residentSplats: residentSplats, budget: budget, device: renderInfo.device) else {
        handleError(.bufferAllocationFailed, "Gaussian shared working set")
        return
    }

    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
    computeEncoder.label = "Gaussian Frustum Culling"

    // Chunked (.untoldgs) entities cull chunk by chunk and are fitted to the budget; their
    // kernels and the frame's budget state are needed for that. A frame without them draws
    // only the whole-buffer entities (a chunked entity is never loaded without the kernels).
    let chunkPipelines = GaussianChunkCullPipelineStates.current()
    let budgetState = workingSet.budgetState
    let frameSlot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
    if let chunkPipelines, let budgetState {
        encodeGaussianBudgetReset(computeEncoder, pipelines: chunkPipelines, budgetState: budgetState)
        profileTotals.dispatchCount += 1
    }
    let hzb = gaussianHZBInputs()

    var chunkedEntities: [GaussianChunkedEntityFrame] = []
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
        profileTotals.include(component: gaussianComponent)
        activeSplatTotal += activeGaussianSortCount(gaussianComponent)
        let matrices = GaussianEntityFrameMatrices(worldTransform: worldTransformComponent, cameraComponent: cameraComponent)

        if gaussianComponent.isChunked {
            guard let chunkPipelines, let budgetState, let chunkTable = gaussianComponent.chunkTable,
                  frameSlot < chunkTable.visibleChunks.count, frameSlot < chunkTable.visibleChunkSets.count
            else {
                handleError(.pipelineStateNulled, "Gaussian chunk kernels")
                continue
            }
            // Chunk level: one thread per chunk appends the chunks whose padded box passes either
            // eye's frustum (and the HZB) to this slot's visible-chunk list and finalizes it into
            // indirect arguments, adding the entity's visible splat total to the frame's budget
            // request. The quotas follow once every entity's request is in; the fused per-chunk
            // pass in executeGaussianPreprocess then decodes, tests and compacts the survivors.
            // A hidden entity (opacityScale 0: resident but not shown) lists no chunk at all.
            let visibleChunks = chunkTable.visibleChunks[frameSlot]
            let chunkSet = chunkTable.visibleChunkSets[frameSlot]
            let chunkConstants = gaussianChunkCullConstants(
                chunkTable: chunkTable,
                modelMatrix: matrices.modelMatrix,
                viewMatrix: matrices.viewMatrix,
                hzbValid: hzb.valid,
                forceAllVisible: gaussianComponent.opacityScale <= 0 ? false : GaussianDebugOptions.shared.disableChunkCull
            )
            if gaussianComponent.opacityScale <= 0 {
                profileTotals.dispatchCount += encodeGaussianEmptyChunkSet(computeEncoder, pipelines: chunkPipelines, chunkSet: chunkSet, budgetState: budgetState)
                gaussianComponent.visibleSplatCountForRendering = 0
                continue
            }
            profileTotals.dispatchCount += encodeGaussianChunkCull(
                computeEncoder,
                pipelines: chunkPipelines,
                chunkTable: chunkTable,
                visibleChunks: visibleChunks,
                chunkSet: chunkSet,
                budgetState: budgetState,
                constants: chunkConstants,
                hzbTexture: hzb.texture
            )
            chunkedEntities.append(GaussianChunkedEntityFrame(chunkTable: chunkTable, visibleChunks: visibleChunks, chunkSet: chunkSet))
            // The record's first word is the quota sum once the quotas are in: an upper bound on
            // what the fused pass appends for this entity.
            visibleCountUpdates.append(
                GaussianVisibleCountUpdate(
                    entityId: entityId,
                    component: gaussianComponent,
                    visibleCount: chunkSet,
                    splatCount: gaussianComponent.splatCount
                )
            )
            continue
        }

        // Whole-buffer entities (.ply, CPU-decoded .untoldgs): the per-splat cull over the
        // encoded buffer into the per-slot visible-index list. Cull/depth-key/radix-sort write
        // these buffers fresh every frame; slot per in-flight frame (mirrors spaceUniform's
        // indexing) so an overlapping newer frame can't clobber data an older in-flight frame's
        // draw is still reading — see the comment on GaussianComponent's declaration.
        guard !gaussianComponent.gaussianVisibleIndices.isEmpty,
              !gaussianComponent.gaussianVisibleCount.isEmpty
        else {
            handleError(.bufferAllocationFailed, "Gaussian culling buffers")
            continue
        }
        let entitySlot = min(renderInfo.currentInFlightFrameSlot, gaussianComponent.gaussianVisibleIndices.count - 1)
        guard let encodedSplatData = gaussianComponent.encodedSplatData,
              let visibleIndices = gaussianComponent.gaussianVisibleIndices[entitySlot],
              let visibleCount = gaussianComponent.gaussianVisibleCount[entitySlot]
        else {
            handleError(.bufferAllocationFailed, "Gaussian culling buffers")
            continue
        }

        computeEncoder.setComputePipelineState(resetPipelineState)
        computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
        computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
        profileTotals.dispatchCount += 1

        // A hidden entity (opacityScale 0: resident but not shown) keeps a zero visible set:
        // the finalize below derives empty indirect arguments from the reset count, so the
        // preprocess and draw skip it without walking its splats.
        if gaussianComponent.opacityScale <= 0 {
            computeEncoder.setComputePipelineState(finalizePipelineState)
            computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
            computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
            profileTotals.dispatchCount += 1
            gaussianComponent.visibleSplatCountForRendering = 0
            continue
        }

        // Coarse per-splat HZB occlusion pre-cull, fused into the per-splat dispatch — see
        // the comment in gaussianClipCentrePassesCull (BitonicSort.metal). Reuses the exact
        // same temporal HZB pyramid mesh occlusion culling builds each frame
        // (buildHZBDepthPyramid); hzbIsValid guarantees hzbDepthPyramid is non-nil when
        // true, so the fallback texture is only ever actually read when the flag (and
        // therefore the shader's own occlusion branch) is off.
        let splatCullInputs = GaussianSplatCullInputs(
            uniforms: matrices.uniforms,
            totalSplats: UInt32(gaussianComponent.splatCount),
            hzbReverseZ: renderInfo.reverseZEnabled ? 1 : 0,
            hzbValid: hzb.valid ? 1 : 0
        )
        bindGaussianSplatCullInputs(
            computeEncoder,
            pipelineState: cullPipelineState,
            inputs: splatCullInputs,
            encodedSplatData: encodedSplatData,
            visibleIndices: visibleIndices,
            visibleCount: visibleCount,
            hzbTexture: hzb.texture
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

    // Every chunked entity's request is in: fit them to the capacity. The scale kernel smooths
    // the frame's target against the previous frame's scale, each entity's quota pass grants its
    // visible chunks floor(scale × splats), and the state is published for this slot's readback.
    if let chunkPipelines, let budgetState {
        encodeGaussianBudgetScale(computeEncoder, pipelines: chunkPipelines, budgetState: budgetState, constants: gaussianBudgetScaleConstants(budget: capacity))
        profileTotals.dispatchCount += 1
        for chunked in chunkedEntities {
            encodeGaussianChunkQuotas(
                computeEncoder,
                pipelines: chunkPipelines,
                chunkTable: chunked.chunkTable,
                visibleChunks: chunked.visibleChunks,
                chunkSet: chunked.chunkSet,
                budgetState: budgetState
            )
            profileTotals.dispatchCount += 1
        }
        if let readback = workingSet.budgetReadback(slot: frameSlot) {
            encodeGaussianBudgetPublish(computeEncoder, pipelines: chunkPipelines, budgetState: budgetState, readback: readback)
            profileTotals.dispatchCount += 1
        }
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
        extra: "previousActiveSplats=\(activeSplatTotal) budget=\(budget) capacity=\(capacity) resident=\(residentSplats) chunkedEntities=\(chunkedEntities.count)"
    )
}

/// The real-world lighting estimate's colour, for splat entities that opt in through
/// `GaussianComponent.useRealWorldTint`: available only while the lighting store's mode is
/// `.realWorldEstimate` and the latest estimate is valid, so a splat shown on the Mac, or in XR
/// with static IBL, keeps its captured colour.
func gaussianRealWorldTint() -> SIMD3<Float>? {
    let store = RuntimeEnvironmentLightingStore.shared
    guard store.mode == .realWorldEstimate,
          let lighting = store.latestXRLighting(),
          lighting.isValid
    else { return nil }
    return lighting.tintColor
}

/// The budget state of a completed frame, read from the slot the frame published to.
private struct GaussianBudgetReadback: @unchecked Sendable {
    let buffer: MTLBuffer?
}

/// Compacts every entity's visible splats into the frame's shared working set. A whole-buffer
/// entity dispatches one thread per entry of its cull list (indirect from its GaussianVisibleSet)
/// through `gaussianPreprocess`; a chunked entity dispatches one threadgroup per visible chunk
/// (indirect from its chunk record) through `gaussianChunkDecodePreprocess`, which decodes the
/// first quota records of the chunk, tests each against the frame's views and projects the
/// survivors. Both compute the footprint and colour once for the head-centre view and append a
/// GaussianWorkingSetSplat record and a depth key. Runs after executeGaussianFrustumCulling and
/// before executeRadixSort, which sorts the shared keys once for all entities.
public func executeGaussianPreprocess(_ commandBuffer: MTLCommandBuffer) {
    let profileStart = gaussianProfilingStartTime()
    var profileTotals = GaussianProfileTotals()
    var activeSplatTotal = 0

    guard gaussianPreprocessPipeline.success else {
        handleError(.pipelineStateNulled, gaussianPreprocessPipeline.name!); return
    }
    guard gaussianFinalizeSharedVisibleSetPipeline.success else {
        handleError(.pipelineStateNulled, gaussianFinalizeSharedVisibleSetPipeline.name!); return
    }
    guard gaussianResetVisibleCountPipeline.success else {
        handleError(.pipelineStateNulled, gaussianResetVisibleCountPipeline.name!); return
    }
    guard let camera = CameraSystem.shared.activeCamera,
          let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
    else {
        handleError(.noActiveCamera)
        return
    }
    guard let preprocessPipelineState = gaussianPreprocessPipeline.pipelineState,
          let finalizePipelineState = gaussianFinalizeSharedVisibleSetPipeline.pipelineState,
          let resetPipelineState = gaussianResetVisibleCountPipeline.pipelineState
    else {
        handleError(.pipelineStateNulled, "Gaussian preprocess pipeline state is nil")
        return
    }

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)
    guard !entities.isEmpty else { return }

    let workingSet = GaussianSharedWorkingSet.shared
    let frameSlot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
    guard let sharedKeys = workingSet.keys(slot: frameSlot),
          let sharedRecords = workingSet.records(slot: frameSlot),
          let sharedVisibleSet = workingSet.visibleSet(slot: frameSlot)
    else {
        handleError(.bufferAllocationFailed, "Gaussian shared working set")
        return
    }
    let capacityValue = workingSet.capacity
    var capacity = UInt32(capacityValue)
    let chunkPipelines = GaussianChunkCullPipelineStates.current()
    let hzb = gaussianHZBInputs()

    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
    computeEncoder.label = "Gaussian Preprocess"

    // Zero the shared set's append counter on this same serial encoder, so the reset can never
    // be skipped independently of the appends that follow it.
    computeEncoder.setComputePipelineState(resetPipelineState)
    computeEncoder.setBuffer(sharedVisibleSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    profileTotals.dispatchCount += 1

    let realWorldTint = gaussianRealWorldTint()

    // The draw resolves each record's entity index through this exact enumeration, even on a
    // later frame that reuses the slot without re-running the preprocess.
    workingSet.setEntityOrder(Array(entities.prefix(Int(gaussianMaxEntitiesPerFrame))), slot: frameSlot)

    let colorByLOD = SpatialDebugVisualization.shared.colorRenderablesByLOD
    let viewport = renderInfo.viewPort ?? simd_float2(1, 1)

    for (entityIndex, entityId) in entities.enumerated() {
        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noGaussianComponent, entityId)
            continue
        }
        profileTotals.include(component: gaussianComponent)

        // The draw looks the entity up by this index (see gaussianExecution); both walk the
        // same query in the same frame. Entities past the table are skipped this frame.
        guard entityIndex < Int(gaussianMaxEntitiesPerFrame) else {
            handleError(.bufferAllocationFailed, "more than \(gaussianMaxEntitiesPerFrame) Gaussian entities in one frame")
            break
        }

        // Sized on the GPU from this frame's cull (dispatchOverVisibleSplats, the chunk record);
        // the CPU count is a stale readback and only feeds the profile line.
        let splatCount = Int(gaussianComponent.splatCount)
        guard splatCount > 0 else { continue }
        activeSplatTotal += activeGaussianSortCount(gaussianComponent)

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }

        // Same effectiveViewMatrix/effectiveCameraPosition requirement as the cull pass — see
        // GaussianEntityFrameMatrices. This is the head-centre view: the footprint and colour
        // are computed once; the draw re-projects the centre per eye.
        let matrices = GaussianEntityFrameMatrices(worldTransform: worldTransformComponent, cameraComponent: cameraComponent)
        var gaussianUniform = matrices.uniforms
        var localNumGaussians = UInt32(splatCount)
        var viewportBytes = viewport
        var shMetadata = gaussianComponent.sphericalHarmonicsMetadata ?? GaussianSHMetadata(
            degree: 0,
            coefficientsPerChannel: 0,
            higherOrderCoefficientsPerSplat: 0,
            _pad0: 0
        )
        var localCameraPosition = gaussianLocalCameraPosition(
            cameraWorldPosition: matrices.effectiveCameraPosition,
            modelMatrix: matrices.modelMatrix
        )

        var entityConstants = GaussianPreprocessEntityConstants()
        entityConstants.entityIndex = UInt32(entityIndex)
        entityConstants.workingSetCapacity = capacity
        var gain = gaussianComponent.colorGain
        if gaussianComponent.useRealWorldTint, let realWorldTint {
            gain *= realWorldTint
        }
        entityConstants.colorGain = simd_float4(gain.x, gain.y, gain.z, 1)
        entityConstants.opacityScale = max(0, gaussianComponent.opacityScale)
        if colorByLOD, let gaussianLOD = scene.get(component: GaussianLODComponent.self, for: entityId) {
            let color = RenderPasses.lodDebugColor(for: gaussianLOD.currentLOD)
            entityConstants.debugColorEnabled = 1
            entityConstants.debugColor = simd_float4(color.x, color.y, color.z, 1.0)
        }

        if gaussianComponent.isChunked {
            guard let chunkPipelines, let chunkTable = gaussianComponent.chunkTable,
                  let packedSplats = gaussianComponent.packedSplatData,
                  frameSlot < chunkTable.visibleChunks.count, frameSlot < chunkTable.visibleChunkSets.count
            else {
                handleError(.pipelineStateNulled, "Gaussian chunk kernels")
                continue
            }
            // Same frame, same matrices as the chunk cull: the per-splat test inside the fused
            // pass uses the eye view-projections (either eye in stereo) and the HZB the chunk
            // stage used, and the projection the head-centre uniforms above.
            let inputs = GaussianChunkPreprocessInputs(
                packedSplats: packedSplats,
                chunkTable: chunkTable,
                visibleChunks: chunkTable.visibleChunks[frameSlot],
                uniforms: gaussianUniform,
                cullConstants: gaussianChunkCullConstants(
                    chunkTable: chunkTable,
                    modelMatrix: matrices.modelMatrix,
                    viewMatrix: matrices.viewMatrix,
                    hzbValid: hzb.valid
                ),
                viewport: viewport,
                sphericalHarmonics: gaussianComponent.sphericalHarmonicsData,
                shMetadata: shMetadata,
                localCameraPosition: localCameraPosition,
                entityConstants: entityConstants,
                hzbTexture: hzb.texture
            )
            encodeGaussianChunkDecodePreprocess(
                computeEncoder,
                pipelineState: chunkPipelines.decodePreprocess,
                inputs: inputs,
                chunkSet: chunkTable.visibleChunkSets[frameSlot],
                sharedRecords: sharedRecords,
                sharedKeys: sharedKeys,
                sharedVisibleSet: sharedVisibleSet
            )
            profileTotals.dispatchCount += 1
            continue
        }

        // Whole-buffer entities: same frame-slot indexing as executeGaussianFrustumCulling —
        // must match, since this reads that same frame's cull output.
        guard !gaussianComponent.gaussianVisibleIndices.isEmpty, !gaussianComponent.gaussianVisibleCount.isEmpty else {
            handleError(.bufferAllocationFailed, "Gaussian preprocess buffers")
            continue
        }
        let entitySlot = min(renderInfo.currentInFlightFrameSlot, gaussianComponent.gaussianVisibleIndices.count - 1)
        guard let encodedSplatData = gaussianComponent.encodedSplatData,
              let visibleIndices = gaussianComponent.gaussianVisibleIndices[entitySlot],
              let visibleCount = gaussianComponent.gaussianVisibleCount[min(entitySlot, gaussianComponent.gaussianVisibleCount.count - 1)]
        else {
            handleError(.bufferAllocationFailed, "Gaussian preprocess buffers")
            continue
        }

        computeEncoder.setComputePipelineState(preprocessPipelineState)
        computeEncoder.setBuffer(encodedSplatData, offset: 0, index: Int(gaussianPreprocessSplatIndex.rawValue))
        computeEncoder.setBytes(&gaussianUniform, length: MemoryLayout<Uniforms>.stride, index: Int(gaussianPreprocessUniformIndex.rawValue))
        computeEncoder.setBytes(&localNumGaussians, length: MemoryLayout<UInt32>.stride, index: Int(gaussianPreprocessNumOfSplatsIndex.rawValue))
        computeEncoder.setBuffer(visibleIndices, offset: 0, index: Int(gaussianPreprocessVisibleIndicesIndex.rawValue))
        computeEncoder.setBuffer(visibleCount, offset: 0, index: Int(gaussianPreprocessVisibleCountIndex.rawValue))
        computeEncoder.setBytes(&viewportBytes, length: MemoryLayout<simd_float2>.stride, index: Int(gaussianPreprocessViewportIndex.rawValue))
        computeEncoder.setBuffer(
            gaussianComponent.sphericalHarmonicsData ?? encodedSplatData,
            offset: 0,
            index: Int(gaussianPreprocessSHIndex.rawValue)
        )
        computeEncoder.setBytes(&shMetadata, length: MemoryLayout<GaussianSHMetadata>.stride, index: Int(gaussianPreprocessSHMetadataIndex.rawValue))
        computeEncoder.setBytes(&localCameraPosition, length: MemoryLayout<simd_float3>.stride, index: Int(gaussianPreprocessLocalCameraIndex.rawValue))
        computeEncoder.setBytes(&entityConstants, length: MemoryLayout<GaussianPreprocessEntityConstants>.stride, index: Int(gaussianPreprocessEntityConstantsIndex.rawValue))
        computeEncoder.setBuffer(sharedRecords, offset: 0, index: Int(gaussianPreprocessWorkingSetIndex.rawValue))
        computeEncoder.setBuffer(sharedKeys, offset: 0, index: Int(gaussianPreprocessSharedKeysIndex.rawValue))
        computeEncoder.setBuffer(sharedVisibleSet, offset: 0, index: Int(gaussianPreprocessSharedVisibleSetIndex.rawValue))

        dispatchOverVisibleSplats(
            computeEncoder,
            pipelineState: preprocessPipelineState,
            visibleSet: visibleCount,
            splatCount: splatCount
        )
        profileTotals.dispatchCount += 1
    }

    // Same serial encoder, so this sees every entity's appends: clamps the shared count to the
    // capacity, records the overflow and derives the sort and draw arguments for the frame.
    computeEncoder.setComputePipelineState(finalizePipelineState)
    computeEncoder.setBuffer(sharedVisibleSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    computeEncoder.setBytes(&capacity, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))
    computeEncoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    profileTotals.dispatchCount += 1

    computeEncoder.endEncoding()

    // Profiling readback of the shared set and the budget state, two or three frames late like
    // the per-entity one. Overflow means splats were dropped this frame: reported once per
    // change, not every frame, and not while the budget scale is still settling toward its
    // target (the quotas then deliberately lag the budget for a few frames and the clamp is
    // doing its job).
    let completedVisibleSet = GaussianSharedVisibleSetReadback(buffer: sharedVisibleSet)
    let completedBudget = GaussianBudgetReadback(buffer: chunkPipelines == nil ? nil : workingSet.budgetReadback(slot: frameSlot))
    commandBuffer.addCompletedHandler { _ in
        let set = completedVisibleSet.buffer.contents().load(as: GaussianVisibleSet.self)
        let budgetState = completedBudget.buffer?.contents().load(as: GaussianBudgetState.self)
        let previousOverflow = GaussianSharedWorkingSet.shared.lastOverflowCount
        GaussianSharedWorkingSet.shared.recordCompletedFrame(visibleCount: Int(set.visibleCount), overflowCount: Int(set.overflowCount), budgetState: budgetState)
        let settling = budgetState.map { $0.scale != $0.targetScale } ?? false
        if set.overflowCount > 0, Int(set.overflowCount) != previousOverflow, !settling {
            handleError(.bufferAllocationFailed, "Gaussian shared working set overflowed: \(set.overflowCount) visible splats dropped (capacity \(capacityValue))")
        }
    }

    profileTotals.sharedWorkingSetBytes = workingSet.residentBytes
    let lastBudget = workingSet.lastBudgetState
    logGaussianProfile(
        stage: "Preprocess",
        startTime: profileStart,
        totals: profileTotals,
        extra: String(
            format: "activeSplats=%d sharedCapacity=%d lastShared=%d lastOverflow=%d budget=%u requested=%u quota=%u scale=%.3f targetScale=%.3f",
            activeSplatTotal, workingSet.capacity, workingSet.lastVisibleCount, workingSet.lastOverflowCount,
            lastBudget.budget, lastBudget.requestedSplats, lastBudget.quotaSplats, lastBudget.scale, lastBudget.targetScale
        )
    )
}

/// The depth keys are written by `executeGaussianPreprocess` into the shared working set since
/// the sort became shared across entities; kept so existing frame loops keep compiling.
@available(*, deprecated, message: "Depth keys are written by executeGaussianPreprocess; remove this call.")
public func executeGaussianDepth(_: MTLCommandBuffer) {}

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

    // One sort for every entity: the shared key buffer the preprocess filled this frame,
    // sized by the shared GaussianVisibleSet on the GPU. `n` only sizes the scratch buffers.
    let workingSet = GaussianSharedWorkingSet.shared
    let n = workingSet.capacity
    guard n >= 2 else { return }
    let frameSlot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
    guard let sortedIndices = workingSet.keys(slot: frameSlot),
          let visibleSet = workingSet.visibleSet(slot: frameSlot)
    else { return }

    // Ping-pong temp buffer (CPU alloc before encoding)
    let keyBufLen = n * MemoryLayout<UInt64>.stride
    if radixSortTempBuffer == nil || radixSortTempBuffer!.length < keyBufLen {
        radixSortTempBuffer = renderInfo.device.makeBuffer(
            length: keyBufLen, options: .storageModeShared
        )
    }
    guard let tempBuffer = radixSortTempBuffer else { return }

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
    guard let perTGBuf = radixPerTGHistBuffer else { return }
    profileTotals.scratchBytes = tempBuffer.length + histBuffer.length + perTGBuf.length
    profileTotals.sharedWorkingSetBytes = workingSet.residentBytes

    var numBuckets = UInt32(256)

    // Single compute encoder for all passes. Dispatches within one encoder execute
    // sequentially on the GPU, so no inter-encoder synchronisation is needed.
    guard let enc = commandBuffer.makeComputeCommandEncoder() else { return }
    enc.label = "Radix Sort"

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

    enc.endEncoding()
    logGaussianProfile(
        stage: "RadixSort",
        startTime: profileStart,
        totals: profileTotals,
        extra: "sharedCapacity=\(n) lastShared=\(workingSet.lastVisibleCount)"
    )
}
