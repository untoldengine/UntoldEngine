//
//  ScenePickingGPUSystem.swift
//  UntoldEngine
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

private enum ScenePickingCandidateMode: UInt64 {
    case visible = 1
    case gizmoOnly = 2
}

private struct ScenePickingCacheState {
    var built = false
    var mode: ScenePickingCandidateMode = .visible
    var signature: UInt64 = 0
}

private struct ScenePickingBuildState {
    var inFlight = false
    var pendingMode: ScenePickingCandidateMode = .visible
    var pendingSignature: UInt64 = 0
}

enum ScenePickGPUQueryResult {
    case hit(ScenePickHit)
    case miss
    case pending
    case error
}

private var scenePickingCacheState = ScenePickingCacheState()
private var scenePickingBuildState = ScenePickingBuildState()
private var scenePickingLastBuildCommandBuffer: MTLCommandBuffer?
private var scenePickingAsyncQueryCommandBuffer: MTLCommandBuffer?

func scenePickingCanUseGPU() -> Bool {
    scenePickingSystemInitialized
        && scenePickingGPUAvailable
        && scenePickingPipeline.success
        && scenePickingPipeline.pipelineState != nil
        && renderInfo.commandQueue != nil
}

func initScenePickingGPUResources() {
    scenePickingGPUAvailable = false
    scenePickingBuildState = ScenePickingBuildState()
    scenePickingLastBuildCommandBuffer = nil
    scenePickingAsyncQueryCommandBuffer = nil

    guard renderInfo.device != nil else {
        handleError(.metalDeviceNotFound)
        return
    }

    guard renderInfo.library != nil else {
        handleError(.metalLibraryNotFound)
        return
    }

    guard renderInfo.device.supportsRaytracing else {
        return
    }

    createComputePipeline(
        into: &scenePickingPipeline,
        device: renderInfo.device,
        library: renderInfo.library,
        functionName: "rayModelIntersectKernel",
        pipelineName: "Scene Picking GPU Pipeline"
    )

    guard scenePickingPipeline.success else { return }

    let outputLength = MemoryLayout<RayModelPickOutput>.stride
    let outputBuffer = renderInfo.device.makeBuffer(length: outputLength, options: .storageModeShared)
    bufferResources.rayModelPickOutputBuffer = outputBuffer
    // Keep compatibility with editor code while migration is in progress.
    bufferResources.rayModelInstanceBuffer = outputBuffer

    guard let outputBuffer else {
        handleError(.bufferAllocationFailed, "Scene Picking GPU output buffer")
        return
    }

    let outputPointer = outputBuffer.contents().assumingMemoryBound(to: RayModelPickOutput.self)
    outputPointer.pointee.instanceHit = -1
    outputPointer.pointee.distance = Float.infinity
    outputPointer.pointee.triangleIndex = 0
    outputPointer.pointee.barycentric = .zero

    scenePickingCacheState = ScenePickingCacheState()
    scenePickingGPUAvailable = true
}

func shutdownScenePickingGPUResources() {
    scenePickingCleanupAccelStructures()
    bufferResources.rayModelPickOutputBuffer = nil
    bufferResources.rayModelInstanceBuffer = nil
    scenePickingPipeline = ComputePipeline()
    scenePickingCacheState = ScenePickingCacheState()
    scenePickingBuildState = ScenePickingBuildState()
    scenePickingLastBuildCommandBuffer = nil
    scenePickingAsyncQueryCommandBuffer = nil
    scenePickingGPUAvailable = false
}

private func scenePickingNewAccelerationStructure(
    _ descriptor: MTLAccelerationStructureDescriptor,
    _ name: String
) -> MTLAccelerationStructure? {
    let accelSize = renderInfo.device.accelerationStructureSizes(descriptor: descriptor)

    guard let accelerationStructure = renderInfo.device.makeAccelerationStructure(
        size: accelSize.accelerationStructureSize
    ) else {
        return nil
    }

    accelerationStructure.label = name

    guard let scratchBuffer = renderInfo.device.makeBuffer(
        length: accelSize.buildScratchBufferSize,
        options: .storageModePrivate
    ) else {
        return nil
    }

    guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
          let commandEncoder = commandBuffer.makeAccelerationStructureCommandEncoder()
    else {
        return nil
    }

    commandEncoder.build(
        accelerationStructure: accelerationStructure,
        descriptor: descriptor,
        scratchBuffer: scratchBuffer,
        scratchBufferOffset: 0
    )
    commandEncoder.endEncoding()

    commandBuffer.commit()
    scenePickingLastBuildCommandBuffer = commandBuffer

    return accelerationStructure.size == 0 ? nil : accelerationStructure
}

private enum ScenePickingBuildFinalizeResult {
    case ready
    case pending
    case failed
}

private func scenePickingTryFinalizeBuild(waitForCompletion: Bool) -> ScenePickingBuildFinalizeResult {
    guard scenePickingBuildState.inFlight else { return .ready }
    guard let commandBuffer = scenePickingLastBuildCommandBuffer else {
        scenePickingBuildState.inFlight = false
        scenePickingCacheState.built = true
        scenePickingCacheState.mode = scenePickingBuildState.pendingMode
        scenePickingCacheState.signature = scenePickingBuildState.pendingSignature
        scenePickingDirtyEntities.removeAll()
        return .ready
    }

    if waitForCompletion {
        commandBuffer.waitUntilCompleted()
    } else {
        switch commandBuffer.status {
        case .completed:
            break
        case .error:
            break
        case .notEnqueued, .enqueued, .committed, .scheduled:
            return .pending
        @unknown default:
            return .pending
        }
    }

    scenePickingLastBuildCommandBuffer = nil

    if commandBuffer.status == .error || commandBuffer.error != nil {
        scenePickingCleanupAccelStructures()
        return .failed
    }

    scenePickingBuildState.inFlight = false
    scenePickingCacheState.built = true
    scenePickingCacheState.mode = scenePickingBuildState.pendingMode
    scenePickingCacheState.signature = scenePickingBuildState.pendingSignature
    scenePickingDirtyEntities.removeAll()
    return .ready
}

private func scenePickingCandidateMode(_ options: ScenePickOptions) -> ScenePickingCandidateMode {
    if options.gizmoOnly || (options.isGizmoActive && !InputSystem.shared.keyState.shiftPressed) {
        return .gizmoOnly
    }

    return .visible
}

private func scenePickingCandidates(_ mode: ScenePickingCandidateMode) -> [EntityID] {
    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)

    if mode == .gizmoOnly {
        let gizmoId = getComponentId(for: GizmoComponent.self)
        return queryEntitiesWithComponentIds([transformId, renderId, gizmoId], in: scene)
            .filter { !scenePickingShouldIgnoreEntityForRayPicking($0) }
    }

    return visibleEntityIds.filter { !scenePickingShouldIgnoreEntityForRayPicking($0) }
}

@inline(__always)
private func scenePickingHashCombine(_ hash: inout UInt64, _ value: UInt64) {
    hash ^= value
    hash = hash &* 1_099_511_628_211
}

@inline(__always)
private func scenePickingObjectHash(_ object: AnyObject) -> UInt64 {
    UInt64(bitPattern: Int64(ObjectIdentifier(object).hashValue))
}

private func isStaticEntity(_ entityId: EntityID) -> Bool {
    // Entities with StaticBatchComponent are static and don't move
    hasComponent(entityId: entityId, componentType: StaticBatchComponent.self)
}

private func scenePickingComputeEntitySignature(_ entityId: EntityID) -> UInt64 {
    var hash: UInt64 = 1_469_598_103_934_665_603
    scenePickingHashCombine(&hash, entityId)

    guard scene.mask(for: entityId) != nil else {
        scenePickingHashCombine(&hash, 0xFFFF_FFFF_FFFF_FFFE)
        return hash
    }

    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
          let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId)
    else {
        scenePickingHashCombine(&hash, 0xFFFF_FFFF_FFFF_FFFD)
        return hash
    }

    scenePickingHashCombine(&hash, renderComponent.isVisible ? 1 : 0)
    scenePickingHashCombine(&hash, UInt64(renderComponent.mesh.count))
    scenePickingHashCombine(&hash, scenePickingHasTransparentSubmesh(renderComponent) ? 1 : 0)

    // Only hash transform for static entities. Dynamic entities changing position should not
    // trigger acceleration structure rebuilds - the signature stays same, only dirty tracking matters
    if isStaticEntity(entityId) {
        let m = worldTransform.space
        scenePickingHashCombine(&hash, UInt64(m.columns.0.x.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.0.y.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.0.z.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.0.w.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.1.x.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.1.y.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.1.z.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.1.w.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.2.x.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.2.y.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.2.z.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.2.w.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.3.x.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.3.y.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.3.z.bitPattern))
        scenePickingHashCombine(&hash, UInt64(m.columns.3.w.bitPattern))
    }

    let positionVertexBufferIndex = Int(modelPassVerticesIndex.rawValue)

    for mesh in renderComponent.mesh {
        scenePickingHashCombine(&hash, UInt64(mesh.submeshes.count))
        scenePickingHashCombine(&hash, UInt64(mesh.metalKitMesh.vertexCount))

        if mesh.metalKitMesh.vertexBuffers.count > positionVertexBufferIndex {
            let vertexBuffer = mesh.metalKitMesh.vertexBuffers[positionVertexBufferIndex].buffer
            scenePickingHashCombine(&hash, scenePickingObjectHash(vertexBuffer))
            scenePickingHashCombine(&hash, UInt64(vertexBuffer.length))
        } else {
            scenePickingHashCombine(&hash, 0xFFFF_FFFF_FFFF_FFFC)
        }

        for submesh in mesh.submeshes {
            scenePickingHashCombine(&hash, UInt64(submesh.metalKitSubmesh.indexCount))
            let indexBuffer = submesh.metalKitSubmesh.indexBuffer.buffer
            scenePickingHashCombine(&hash, scenePickingObjectHash(indexBuffer))
            scenePickingHashCombine(&hash, UInt64(indexBuffer.length))
        }
    }

    return hash
}

private func scenePickingComputeSignature(
    candidates: [EntityID],
    mode: ScenePickingCandidateMode
) -> UInt64 {
    var hash: UInt64 = 1_469_598_103_934_665_603

    scenePickingHashCombine(&hash, mode.rawValue)
    scenePickingHashCombine(&hash, UInt64(candidates.count))
    scenePickingHashCombine(&hash, scenePickingIgnoreRayIntersectionWithTransparents ? 1 : 0)

    var orderInvariantXor: UInt64 = 0
    var orderInvariantSum: UInt64 = 0

    for entityId in candidates {
        let entityHash = scenePickingComputeEntitySignature(entityId)
        orderInvariantXor ^= entityHash
        orderInvariantSum &+= entityHash &* 1_099_511_628_211
    }

    scenePickingHashCombine(&hash, orderInvariantXor)
    scenePickingHashCombine(&hash, orderInvariantSum)
    return hash
}

private func scenePickingCreateAccelerationStructures(_ candidates: [EntityID]) {
    let positionVertexBufferIndex = Int(modelPassVerticesIndex.rawValue)

    for entityId in candidates {
        if scene.mask(for: entityId) == nil { continue }
        if scenePickingShouldIgnoreEntityForRayPicking(entityId) { continue }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else { continue }
        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) else { continue }
        guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else { continue }
        if !renderComponent.isVisible { continue }
        if scenePickingShouldIgnoreEntityDueToTransparency(renderComponent) { continue }

        var geometryDescriptors: [MTLAccelerationStructureGeometryDescriptor] = []

        for mesh in renderComponent.mesh {
            guard mesh.metalKitMesh.vertexBuffers.count > positionVertexBufferIndex else { continue }

            for submesh in mesh.submeshes {
                let triangleCount = submesh.metalKitSubmesh.indexCount / 3
                guard triangleCount > 0 else { continue }

                let geometryDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()
                geometryDescriptor.vertexBuffer = mesh.metalKitMesh.vertexBuffers[positionVertexBufferIndex].buffer
                geometryDescriptor.vertexStride = MemoryLayout<simd_float4>.stride
                geometryDescriptor.indexBuffer = submesh.metalKitSubmesh.indexBuffer.buffer
                geometryDescriptor.indexType = submesh.metalKitSubmesh.indexType
                geometryDescriptor.triangleCount = triangleCount
                geometryDescriptor.vertexFormat = .float4

                geometryDescriptors.append(geometryDescriptor)
            }
        }

        guard !geometryDescriptors.isEmpty else { continue }

        let finalTransform = worldTransform.space
        let column0 = MTLPackedFloat3Make(finalTransform.columns.0.x, finalTransform.columns.0.y, finalTransform.columns.0.z)
        let column1 = MTLPackedFloat3Make(finalTransform.columns.1.x, finalTransform.columns.1.y, finalTransform.columns.1.z)
        let column2 = MTLPackedFloat3Make(finalTransform.columns.2.x, finalTransform.columns.2.y, finalTransform.columns.2.z)
        let column3 = MTLPackedFloat3Make(finalTransform.columns.3.x, finalTransform.columns.3.y, finalTransform.columns.3.z)
        let transform = MTLPackedFloat4x3(columns: (column0, column1, column2, column3))

        let primitiveDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
        primitiveDescriptor.geometryDescriptors = geometryDescriptors

        guard let accelerationStructure = scenePickingNewAccelerationStructure(
            primitiveDescriptor,
            getEntityName(entityId: entityId)
        ) else {
            continue
        }

        let accelerationStructureIndex = UInt32(scenePickingAccelStructResources.primitiveAccelerationStructures.count)
        scenePickingAccelStructResources.primitiveAccelerationStructures.append(accelerationStructure)
        scenePickingAccelStructResources.instanceTransforms.append(transform)
        scenePickingAccelStructResources.accelerationStructIndex.append(accelerationStructureIndex)
        scenePickingAccelStructResources.entityIDIndex.append(entityId)
        scenePickingAccelStructResources.mask.append(Int32(GEOMETRY_MASK_TRIANGLE))
    }
}

private func scenePickingCreateInstanceAccelerationStructure() {
    guard !scenePickingAccelStructResources.primitiveAccelerationStructures.isEmpty else {
        scenePickingAccelStructResources.instanceBuffer = nil
        scenePickingAccelStructResources.instanceAccelerationStructure = nil
        return
    }

    let descriptorStride = MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride
    let descriptorBufferSize = descriptorStride * scenePickingAccelStructResources.primitiveAccelerationStructures.count

    guard let instanceBuffer = renderInfo.device.makeBuffer(
        length: descriptorBufferSize,
        options: .storageModeShared
    ) else {
        scenePickingAccelStructResources.instanceAccelerationStructure = nil
        handleError(.bufferAllocationFailed, "Scene Picking instance descriptor buffer")
        return
    }

    scenePickingAccelStructResources.instanceBuffer = instanceBuffer
    let descriptors = instanceBuffer.contents().assumingMemoryBound(to: MTLAccelerationStructureInstanceDescriptor.self)

    for (instanceIndex, _) in scenePickingAccelStructResources.primitiveAccelerationStructures.enumerated() {
        descriptors[instanceIndex].accelerationStructureIndex =
            scenePickingAccelStructResources.accelerationStructIndex[instanceIndex]
        descriptors[instanceIndex].mask = UInt32(scenePickingAccelStructResources.mask[instanceIndex])
        descriptors[instanceIndex].transformationMatrix = scenePickingAccelStructResources.instanceTransforms[instanceIndex]
    }

    let instanceDescriptor = MTLInstanceAccelerationStructureDescriptor()
    instanceDescriptor.instancedAccelerationStructures = scenePickingAccelStructResources.primitiveAccelerationStructures
    instanceDescriptor.instanceCount = scenePickingAccelStructResources.primitiveAccelerationStructures.count
    instanceDescriptor.instanceDescriptorBuffer = scenePickingAccelStructResources.instanceBuffer

    scenePickingAccelStructResources.instanceAccelerationStructure = scenePickingNewAccelerationStructure(
        instanceDescriptor,
        "Scene Picking Instance Accel Struct"
    )
}

private func scenePickingEnsureAccelerationStructures(
    _ options: ScenePickOptions,
    waitForRebuildCompletion: Bool
) -> Bool {
    let mode = scenePickingCandidateMode(options)
    let candidates = scenePickingCandidates(mode)
    let signature = scenePickingComputeSignature(candidates: candidates, mode: mode)

    switch scenePickingTryFinalizeBuild(waitForCompletion: waitForRebuildCompletion) {
    case .ready:
        break
    case .pending, .failed:
        return false
    }

    let missingSceneStructures = !candidates.isEmpty
        && (
            scenePickingAccelStructResources.instanceAccelerationStructure == nil
                || scenePickingAccelStructResources.instanceBuffer == nil
        )

    let shouldRebuild =
        scenePickingCacheState.built == false
            || scenePickingCacheState.mode != mode
            || scenePickingCacheState.signature != signature
            || !scenePickingDirtyEntities.isEmpty
            || missingSceneStructures

    guard shouldRebuild else { return true }

    scenePickingCleanupAccelStructures()
    scenePickingCreateAccelerationStructures(candidates)
    scenePickingCreateInstanceAccelerationStructure()

    scenePickingBuildState.inFlight = true
    scenePickingBuildState.pendingMode = mode
    scenePickingBuildState.pendingSignature = signature

    switch scenePickingTryFinalizeBuild(waitForCompletion: waitForRebuildCompletion) {
    case .ready:
        return true
    case .pending, .failed:
        return false
    }
}

func scenePickingCleanupAccelStructures() {
    scenePickingAccelStructResources.primitiveAccelerationStructures.removeAll()
    scenePickingAccelStructResources.instanceTransforms.removeAll()
    scenePickingAccelStructResources.accelerationStructIndex.removeAll()
    scenePickingAccelStructResources.entityIDIndex.removeAll()
    scenePickingAccelStructResources.mask.removeAll()
    scenePickingAccelStructResources.instanceAccelerationStructure = nil
    scenePickingAccelStructResources.instanceBuffer = nil
    scenePickingCacheState.built = false
    scenePickingBuildState = ScenePickingBuildState()
    scenePickingLastBuildCommandBuffer = nil
    scenePickingAsyncQueryCommandBuffer = nil
}

private func scenePickingPollAsyncQuery() {
    guard let commandBuffer = scenePickingAsyncQueryCommandBuffer else { return }

    switch commandBuffer.status {
    case .completed, .error:
        scenePickingAsyncQueryCommandBuffer = nil
    case .notEnqueued, .enqueued, .committed, .scheduled:
        break
    @unknown default:
        break
    }
}

@inline(__always)
private func scenePickingResetOutputBuffer(_ outputBuffer: MTLBuffer) {
    let outputPointer = outputBuffer.contents().assumingMemoryBound(to: RayModelPickOutput.self)
    outputPointer.pointee.instanceHit = -1
    outputPointer.pointee.distance = Float.infinity
    outputPointer.pointee.triangleIndex = 0
    outputPointer.pointee.barycentric = .zero
}

private func scenePickingExecuteRayVsModelHit(
    _ commandBuffer: MTLCommandBuffer,
    _ origin: simd_float3,
    _ direction: simd_float3,
    _ options: ScenePickOptions,
    waitForRebuildCompletion: Bool
) -> Bool {
    guard scenePickingEnsureAccelerationStructures(
        options,
        waitForRebuildCompletion: waitForRebuildCompletion
    ) else {
        return false
    }
    guard let outputBuffer = bufferResources.rayModelPickOutputBuffer else { return false }
    scenePickingResetOutputBuffer(outputBuffer)

    guard scenePickingPipeline.success,
          let pipelineState = scenePickingPipeline.pipelineState,
          let instanceAccelerationStructure = scenePickingAccelStructResources.instanceAccelerationStructure,
          let instanceBuffer = scenePickingAccelStructResources.instanceBuffer
    else {
        return false
    }

    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return false }
    computeEncoder.label = "Scene Picking Ray Hit pass"
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setAccelerationStructure(
        instanceAccelerationStructure,
        bufferIndex: Int(rayModelAccelStructIndex.rawValue)
    )
    computeEncoder.setBuffer(instanceBuffer, offset: 0, index: Int(rayModelBufferInstanceIndex.rawValue))

    var rayOrigin = origin
    var rayDirection = simd_normalize(direction)
    computeEncoder.setBytes(
        &rayOrigin,
        length: MemoryLayout<simd_float3>.stride,
        index: Int(rayModelOriginIndex.rawValue)
    )
    computeEncoder.setBytes(
        &rayDirection,
        length: MemoryLayout<simd_float3>.stride,
        index: Int(rayModelDirectionIndex.rawValue)
    )

    computeEncoder.setBuffer(
        outputBuffer,
        offset: 0,
        index: Int(rayModelInstanceHitIndex.rawValue)
    )

    let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
    let threadsPerGrid = MTLSize(width: 1, height: 1, depth: 1)
    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    computeEncoder.endEncoding()
    return true
}

/// Perform GPU ray-triangle intersection for a pre-filtered set of candidate entities.
/// Builds a throwaway acceleration structure for only the provided candidates (no signature cache).
func pickEntityGPUWithCandidates(
    candidates: [EntityID],
    rayOrigin: simd_float3,
    normalizedRayDirection: simd_float3,
    options: ScenePickOptions
) -> ScenePickHit? {
    guard scenePickingCanUseGPU() else { return nil }
    guard !candidates.isEmpty else { return nil }

    // Save current accel-struct state so we can restore it after this one-shot query.
    let savedPrimitive = scenePickingAccelStructResources.primitiveAccelerationStructures
    let savedTransforms = scenePickingAccelStructResources.instanceTransforms
    let savedAccelIndex = scenePickingAccelStructResources.accelerationStructIndex
    let savedEntityIndex = scenePickingAccelStructResources.entityIDIndex
    let savedMask = scenePickingAccelStructResources.mask
    let savedInstanceBuffer = scenePickingAccelStructResources.instanceBuffer
    let savedInstanceAccel = scenePickingAccelStructResources.instanceAccelerationStructure

    // Clear and build for candidates only.
    scenePickingAccelStructResources.primitiveAccelerationStructures.removeAll()
    scenePickingAccelStructResources.instanceTransforms.removeAll()
    scenePickingAccelStructResources.accelerationStructIndex.removeAll()
    scenePickingAccelStructResources.entityIDIndex.removeAll()
    scenePickingAccelStructResources.mask.removeAll()
    scenePickingAccelStructResources.instanceBuffer = nil
    scenePickingAccelStructResources.instanceAccelerationStructure = nil

    scenePickingCreateAccelerationStructures(candidates)
    scenePickingCreateInstanceAccelerationStructure()

    // Wait for the build to finish (cheap with few entities).
    scenePickingLastBuildCommandBuffer?.waitUntilCompleted()
    scenePickingLastBuildCommandBuffer = nil

    defer {
        // Restore previous accel-struct state.
        scenePickingAccelStructResources.primitiveAccelerationStructures = savedPrimitive
        scenePickingAccelStructResources.instanceTransforms = savedTransforms
        scenePickingAccelStructResources.accelerationStructIndex = savedAccelIndex
        scenePickingAccelStructResources.entityIDIndex = savedEntityIndex
        scenePickingAccelStructResources.mask = savedMask
        scenePickingAccelStructResources.instanceBuffer = savedInstanceBuffer
        scenePickingAccelStructResources.instanceAccelerationStructure = savedInstanceAccel
    }

    guard let outputBuffer = bufferResources.rayModelPickOutputBuffer else { return nil }
    scenePickingResetOutputBuffer(outputBuffer)

    guard scenePickingPipeline.success,
          let pipelineState = scenePickingPipeline.pipelineState,
          let instanceAccelerationStructure = scenePickingAccelStructResources.instanceAccelerationStructure,
          let instanceBuffer = scenePickingAccelStructResources.instanceBuffer
    else {
        return nil
    }

    guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else { return nil }
    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
    computeEncoder.label = "Scene Picking Octree+GPU Ray Hit pass"
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setAccelerationStructure(
        instanceAccelerationStructure,
        bufferIndex: Int(rayModelAccelStructIndex.rawValue)
    )
    computeEncoder.setBuffer(instanceBuffer, offset: 0, index: Int(rayModelBufferInstanceIndex.rawValue))

    var origin = rayOrigin
    var direction = simd_normalize(normalizedRayDirection)
    computeEncoder.setBytes(&origin, length: MemoryLayout<simd_float3>.stride, index: Int(rayModelOriginIndex.rawValue))
    computeEncoder.setBytes(&direction, length: MemoryLayout<simd_float3>.stride, index: Int(rayModelDirectionIndex.rawValue))
    computeEncoder.setBuffer(outputBuffer, offset: 0, index: Int(rayModelInstanceHitIndex.rawValue))

    let threads = MTLSize(width: 1, height: 1, depth: 1)
    computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: threads)
    computeEncoder.endEncoding()

    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    if commandBuffer.error != nil { return nil }

    let output = outputBuffer.contents().assumingMemoryBound(to: RayModelPickOutput.self).pointee
    let hitIndex = Int(output.instanceHit)

    guard hitIndex >= 0,
          hitIndex < scenePickingAccelStructResources.entityIDIndex.count
    else {
        return nil
    }

    guard output.distance.isFinite else { return nil }
    if output.distance > options.maxDistance { return nil }

    let entityId = scenePickingAccelStructResources.entityIDIndex[hitIndex]
    let worldPosition = rayOrigin + normalizedRayDirection * output.distance
    return ScenePickHit(
        entityId: entityId,
        distance: output.distance,
        worldPosition: worldPosition,
        triangleIndex: output.triangleIndex
    )
}

func pickEntityGPU(
    rayOrigin: simd_float3,
    normalizedRayDirection: simd_float3,
    options: ScenePickOptions,
    allowNonBlockingRebuild: Bool = false,
    allowNonBlockingRayQuery: Bool = false
) -> ScenePickGPUQueryResult {
    guard scenePickingCanUseGPU() else { return .error }

    scenePickingPollAsyncQuery()

    if allowNonBlockingRayQuery {
        // Avoid overlapping writes to the shared output buffer.
        if scenePickingAsyncQueryCommandBuffer != nil {
            return .pending
        }
    } else if let inFlightQuery = scenePickingAsyncQueryCommandBuffer {
        inFlightQuery.waitUntilCompleted()
        scenePickingAsyncQueryCommandBuffer = nil
    }

    guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else { return .error }

    guard scenePickingExecuteRayVsModelHit(
        commandBuffer,
        rayOrigin,
        normalizedRayDirection,
        options,
        waitForRebuildCompletion: !allowNonBlockingRebuild
    ) else {
        return allowNonBlockingRebuild ? .pending : .error
    }

    commandBuffer.commit()

    if allowNonBlockingRayQuery {
        scenePickingAsyncQueryCommandBuffer = commandBuffer
        return .pending
    }

    commandBuffer.waitUntilCompleted()

    if commandBuffer.error != nil {
        return .error
    }

    guard let outputBuffer = bufferResources.rayModelPickOutputBuffer else { return .error }
    let output = outputBuffer.contents().assumingMemoryBound(to: RayModelPickOutput.self).pointee
    let hitIndex = Int(output.instanceHit)

    guard hitIndex >= 0,
          hitIndex < scenePickingAccelStructResources.entityIDIndex.count
    else {
        return .miss
    }

    guard output.distance.isFinite else { return .miss }
    if output.distance > options.maxDistance { return .miss }

    let entityId = scenePickingAccelStructResources.entityIDIndex[hitIndex]
    let worldPosition = rayOrigin + normalizedRayDirection * output.distance
    return .hit(ScenePickHit(
        entityId: entityId,
        distance: output.distance,
        worldPosition: worldPosition,
        triangleIndex: output.triangleIndex
    ))
}
