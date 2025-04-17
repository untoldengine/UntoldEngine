//
//  RayModelIntersecions.swift
//
//
//  Created by Harold Serrano on 4/16/25.
//

import CShaderTypes
import Foundation
import Metal

func newAccelerationStructure(
    _ accelerationStructureDescriptor: MTLAccelerationStructureDescriptor, _ name: String
) -> MTLAccelerationStructure? {
    // 1. Query for the sizes needed to store and build the acceleration structure
    let accelSize: MTLAccelerationStructureSizes = renderInfo.device.accelerationStructureSizes(
        descriptor: accelerationStructureDescriptor)

    // 2. Allocate an acceleration structure large enough for the descriptor. It only allocates memory. It does not build the structure
    guard
        let accelerationStructure: MTLAccelerationStructure = renderInfo.device
        .makeAccelerationStructure(size: accelSize.accelerationStructureSize)
    else {
        print("failed to allocate acceleration structure")
        return nil
    }

    accelerationStructure.label = name

    // 3. Allocate scrath space
    guard
        let scratchBuffer: MTLBuffer = renderInfo.device.makeBuffer(
            length: accelSize.buildScratchBufferSize, options: .storageModePrivate
        )
    else {
        print("Failed to allocate scratch buffer")
        return nil
    }

    // 4. Create a command buffer that performs the acceleration structure build
    guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
          let commandEncoder = commandBuffer.makeAccelerationStructureCommandEncoder()
    else {
        print("Failed to create command buffer or command encoder")
        return nil
    }

    // 6. build acceleration structure
    commandEncoder.build(
        accelerationStructure: accelerationStructure, descriptor: accelerationStructureDescriptor,
        scratchBuffer: scratchBuffer, scratchBufferOffset: 0
    )

    // End encoding, and commit the command buffer so the GPU can start building the
    // acceleration structure.
    commandEncoder.endEncoding()
    commandBuffer.commit()

    commandBuffer.waitUntilCompleted()

    if accelerationStructure.size == 0 {
        print("Acceleration structure size is zero after building")
        return nil
    }

    return accelerationStructure
}

// Create acceleration structures for the scene. The scene contains primitive acceleration
// structures and an instance acceleration structure. The primitive acceleration structures
// contain primitives, such as triangles and spheres. The instance acceleration structure contains
// copies, or instances, of the primitive acceleration structures, each with their own
// transformation matrix that describes where to place them in the scene.

func createAccelerationStructures(_: Bool) {
    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

    // Iterate over the entities found by the component query
    for (i, entityId) in entities.enumerated() {
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            continue
        }

        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            continue
        }

        // 1. Create a geometry descriptor
        var geometryDescriptors: [MTLAccelerationStructureGeometryDescriptor] = []

        for mesh in renderComponent.mesh {
            let geometryDescriptor = MTLAccelerationStructureTriangleGeometryDescriptor()

            geometryDescriptor.vertexBuffer = mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer
            geometryDescriptor.vertexStride = MemoryLayout<simd_float4>.stride
            geometryDescriptor.indexBuffer = mesh.submeshes[0].metalKitSubmesh.indexBuffer.buffer
            geometryDescriptor.indexType = mesh.submeshes[0].metalKitSubmesh.indexType
            geometryDescriptor.triangleCount = mesh.submeshes[0].metalKitSubmesh.indexCount / 3
            geometryDescriptor.vertexFormat = .float4

            geometryDescriptors.append(geometryDescriptor)
        }

        let column0: MTLPackedFloat3 = MTLPackedFloat3Make(
            worldTransform.space.columns.0.x, worldTransform.space.columns.0.y, worldTransform.space.columns.0.z
        )
        let column1: MTLPackedFloat3 = MTLPackedFloat3Make(
            worldTransform.space.columns.1.x, worldTransform.space.columns.1.y, worldTransform.space.columns.1.z
        )
        let column2: MTLPackedFloat3 = MTLPackedFloat3Make(
            worldTransform.space.columns.2.x, worldTransform.space.columns.2.y, worldTransform.space.columns.2.z
        )
        let column3: MTLPackedFloat3 = MTLPackedFloat3Make(
            worldTransform.space.columns.3.x, worldTransform.space.columns.3.y, worldTransform.space.columns.3.z
        )

        let localSpace = MTLPackedFloat4x3(
            columns: (column0, column1, column2, column3))

        var mask: Int32 = GEOMETRY_MASK_TRIANGLE

        // 2. Create a primitive acceleration structure
        let accelerationStructureDescriptor =
            MTLPrimitiveAccelerationStructureDescriptor()

        // 3. Add geometry descriptor to acceleration structure descriptor
        accelerationStructureDescriptor.geometryDescriptors = geometryDescriptors

        // build the acceleration structure
        if let accelerationStructure: MTLAccelerationStructure = newAccelerationStructure(
            accelerationStructureDescriptor, getEntityName(entityId: entityId)!
        ) {
            // Add the acceleration structure to the array of primitive acceleration structures.
            accelStructResources.primitiveAccelerationStructures.append(accelerationStructure)
            accelStructResources.instanceTransforms.append(localSpace)
            accelStructResources.accelerationStructIndex.append(UInt32(i))
            accelStructResources.entityIDIndex.append(entityId)
            accelStructResources.mask.append(mask)
            // print("Acceleration structure for \(String(describing: r.mesh.name)) properly created")

        } else {
            print("Failed to create acceleration structure for entity \(String(describing: getEntityName(entityId: entityId)))")
        }
    }
}

func createInstanceAccelerationStructures() {
    // Allocate a buffer of acceleration structure instance descriptors. Each descriptor represents
    // an instance of one of the primitive acceleration structures created above, with its own
    // transformation matrix.

    // 2. ALlocate the instance descriptor buffer
    let size = MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride
    let instanceDescriptorBufferSize =
        size * accelStructResources.primitiveAccelerationStructures.count

    accelStructResources.instanceBuffer = renderInfo.device.makeBuffer(
        length: instanceDescriptorBufferSize, options: .storageModeShared
    )!

    // 3. Populate instance descriptors
    let instaceDescriptorBuffer = accelStructResources.instanceBuffer!.contents().assumingMemoryBound(
        to: MTLAccelerationStructureInstanceDescriptor.self)

    for (instanceIndex, _) in accelStructResources.primitiveAccelerationStructures.enumerated() {
        instaceDescriptorBuffer[instanceIndex].accelerationStructureIndex =
            accelStructResources.accelerationStructIndex[instanceIndex]
        instaceDescriptorBuffer[instanceIndex].mask = UInt32(accelStructResources.mask[instanceIndex])

        let transform = accelStructResources.instanceTransforms[instanceIndex]

        instaceDescriptorBuffer[instanceIndex].transformationMatrix = transform
    }

    // create an instance acceleration structure descriptor
    let instanceAccelDescriptor =
        MTLInstanceAccelerationStructureDescriptor()

    instanceAccelDescriptor.instancedAccelerationStructures =
        accelStructResources.primitiveAccelerationStructures
    instanceAccelDescriptor.instanceCount = accelStructResources.primitiveAccelerationStructures.count
    instanceAccelDescriptor.instanceDescriptorBuffer = accelStructResources.instanceBuffer

    // Create the instance acceleration structure that contains all instances in the scene.
    accelStructResources.instanceAccelerationStructure = newAccelerationStructure(
        instanceAccelDescriptor, "scene instance accel struct"
    )
}

func initRayTracingCompute() {
    // create ray vs model pipeline
    // create kernel
    guard
        let rayModelIntersectKernel = renderInfo.library.makeFunction(name: "rayModelIntersectKernel")
    else {
        handleError(.kernelCreationFailed, rayModelIntersectPipeline.name!)
        return
    }

    // create a pipeline
    do {
        rayModelIntersectPipeline.pipelineState = try renderInfo.device.makeComputePipelineState(
            function: rayModelIntersectKernel)

        rayModelIntersectPipeline.name = "ray vs model intersect pipe"
        rayModelIntersectPipeline.success = true
    } catch {
        rayModelIntersectPipeline.success = false
        handleError(.pipelineStateCreationFailed, rayModelIntersectPipeline.name!)
        return
    }

    bufferResources.rayModelInstanceBuffer = renderInfo.device.makeBuffer(
        length: MemoryLayout<Int32>.stride, options: .storageModeShared
    )
}

func cleanUpAccelStructures() {
    // clean up all acceleration structures resources
    accelStructResources.primitiveAccelerationStructures.removeAll()
    accelStructResources.instanceTransforms.removeAll()
    accelStructResources.accelerationStructIndex.removeAll()
    accelStructResources.entityIDIndex.removeAll()
    accelStructResources.instanceAccelerationStructure = nil
    accelStructResources.instanceBuffer = nil
}

func prepareUserHitRayAccelStructures() {
    // clean up all acceleration structures resources
    cleanUpAccelStructures()

    // create acceleration structures
    createAccelerationStructures(false)

    // create instance acceleration structures
    createInstanceAccelerationStructures()
}

func executeRayVsModelHit(
    _ commandBuffer: MTLCommandBuffer, _ origin: simd_float3, _ direction: simd_float3
) {
    // prepare acceleration structure
    prepareUserHitRayAccelStructures()

    if rayModelIntersectPipeline.success == false {
        handleError(.pipelineStateNulled, rayModelIntersectPipeline.name!)
        return
    }

    // ray tracing
    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "User Ray-Hit pass"

    computeEncoder.setComputePipelineState(rayModelIntersectPipeline.pipelineState!)

    computeEncoder.setAccelerationStructure(
        accelStructResources.instanceAccelerationStructure,
        bufferIndex: Int(rayModelAccelStructIndex.rawValue)
    )

    computeEncoder.setBuffer(
        accelStructResources.instanceBuffer, offset: 0, index: Int(rayModelBufferInstanceIndex.rawValue)
    )

    var rayOrigin = origin
    var rayDirection = direction

    computeEncoder.setBytes(
        &rayOrigin, length: MemoryLayout<simd_float3>.stride, index: Int(rayModelOriginIndex.rawValue)
    )

    computeEncoder.setBytes(
        &rayDirection, length: MemoryLayout<simd_float3>.stride,
        index: Int(rayModelDirectionIndex.rawValue)
    )

    computeEncoder.setBuffer(
        bufferResources.rayModelInstanceBuffer, offset: 0, index: Int(rayModelInstanceHitIndex.rawValue)
    )

    // Set threadExecutionWidth and maxTotalThreadsPerThreadgroup to 1 to dispatch only one thread
    let w = 1
    let h = 1

    let threadsPerThreadgroup: MTLSize = MTLSizeMake(w, h, 1)
    let threadsPerGrid: MTLSize = MTLSizeMake(1, 1, 1) // Dispatch a single thread

    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

    computeEncoder.endEncoding()
}
