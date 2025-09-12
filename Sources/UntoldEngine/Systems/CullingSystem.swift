//
//  CullingSystem.swift
//
//
//  Created by Harold Serrano on 08/18/25.
//

import CShaderTypes
import Foundation
import Metal
import simd

let kInFlight = 3
let planeCount = 6
let planeStride = MemoryLayout<simd_float4>.stride

struct Plane {
    public var n: simd_float3
    public var d: Float // plane: n·x + d = 0
}

struct Frustum {
    var planes: [Plane] // L, R, B, T, N, F
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
                                   worldMatrix M: simd_float4x4) -> (center: simd_float3, halfExtent: simd_float3)
{
    // rotation*scale + translation
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

    // world halfExtent
    let AR = simd_float3x3(rows: [
        simd_float3(abs(R[0, 0]), abs(R[0, 1]), abs(R[0, 2])),
        simd_float3(abs(R[1, 0]), abs(R[1, 1]), abs(R[1, 2])),
        simd_float3(abs(R[2, 0]), abs(R[2, 1]), abs(R[2, 2])),
    ])
    let we = AR * le

    return (wc, we)
}

public func makeObjectAABB(localMin: simd_float3,
                           localMax: simd_float3,
                           worldMatrix M: simd_float4x4,
                           index: UInt32, version: UInt32) -> EntityAABB
{
    let (c, e) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: M)
    return EntityAABB(center: simd_float4(c.x, c.y, c.z, 0.0), halfExtent: simd_float4(e.x, e.y, e.z, 0.0), index: index, version: version, pad0: 0, pad1: 0)
}

func buildFrustum(from viewProj: simd_float4x4) -> Frustum {
    let inv = viewProj.inverse

    func unproject(_ ndc: simd_float3) -> simd_float3 {
        let p = inv * SIMD4(ndc, 1)
        return SIMD3(p.x, p.y, p.z) / p.w
    }

    let zn: Float = 0, zf: Float = 1 // Metal depth goes from 0 to 1.
    let ntl = unproject([-1, 1, zn]), ntr = unproject([1, 1, zn])
    let nbl = unproject([-1, -1, zn]), nbr = unproject([1, -1, zn])
    let ftl = unproject([-1, 1, zf]), ftr = unproject([1, 1, zf])
    let _ = unproject([-1, -1, zf]), fbr = unproject([1, -1, zf])

    func plane(_ a: simd_float3, _ b: simd_float3, _ c: simd_float3) -> Plane {
        let n = normalize(cross(b - a, c - a)) // CCW seen from inside → inward normals
        return Plane(n: n, d: -dot(n, a))
    }

    let left = plane(ftl, ntl, nbl)
    let right = plane(ntr, ftr, fbr)
    let bottom = plane(nbl, nbr, fbr)
    let top = plane(ftr, ntr, ntl)
    let nearP = plane(ntl, ntr, nbr)
    let farP = plane(fbr, ftr, ftl)

    return Frustum(planes: [left, right, bottom, top, nearP, farP])
}

func initFrustumCulllingCompute() {
    // create kernel
    guard
        let frustumCullingKernel = renderInfo.library.makeFunction(name: "cullFrustumAABB")
    else {
        handleError(.kernelCreationFailed, frustumCullingPipeline.name!)
        return
    }

    // create a pipeline
    do {
        frustumCullingPipeline.pipelineState = try renderInfo.device.makeComputePipelineState(
            function: frustumCullingKernel)

        frustumCullingPipeline.name = "Frustum Culling pipe"
        frustumCullingPipeline.success = true
    } catch {
        frustumCullingPipeline.success = false
        handleError(.pipelineStateCreationFailed, frustumCullingPipeline.name!)
        return
    }

    tripleBufferResources.frustumPlane = TripleBuffer<simd_float4>(device: renderInfo.device, initialCapacity: planeCount)

    tripleBufferResources.entityAABB = TripleBuffer(device: renderInfo.device, initialCapacity: MAX_ENTITIES)

    // count
    bufferResources.visibleCountBuffer = renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: .storageModeShared)

    bufferResources.visibilityBuffer = renderInfo.device.makeBuffer(length: MemoryLayout<VisibleEntity>.stride * MAX_ENTITIES, options: .storageModeShared)

    visibleEntityIds.removeAll(keepingCapacity: true)
}

func executeFrustumCulling(_ commandBuffer: MTLCommandBuffer) {
    if frustumCullingPipeline.success == false {
        handleError(.pipelineStateNulled, frustumCullingPipeline.name!)
        return
    }

    guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
        handleError(.noActiveCamera)
        return
    }

    // clear up visible count buffer
    let blit = commandBuffer.makeBlitCommandEncoder()!
    blit.fill(buffer: bufferResources.visibleCountBuffer!, range: 0 ..< MemoryLayout<UInt32>.stride, value: 0)
    blit.endEncoding()

    let viewProjection: simd_float4x4 = simd_mul(renderInfo.perspectiveSpace, cameraComponent.viewSpace)

    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "Frustum Culling pass"

    computeEncoder.setComputePipelineState(frustumCullingPipeline.pipelineState!)

    // build the frustum
    let frustum = buildFrustum(from: viewProjection)

    guard let frustumTripleBuffer = tripleBufferResources.frustumPlane else {
        handleError(.bufferAllocationFailed, "Frustum cull buffer")
        return
    }

    guard let entityAABBTripleBuffer = tripleBufferResources.entityAABB else {
        handleError(.bufferAllocationFailed, "Entity AABB buffer")
        return
    }

    guard let visibilityCountBuffer = bufferResources.visibleCountBuffer else {
        handleError(.bufferAllocationFailed, "visbility count buffer in frustum culling")
        return
    }

    guard let visibilityBuffer = bufferResources.visibilityBuffer else {
        handleError(.bufferAllocationFailed, "visibility buffer in frustum culling")
        return
    }

    let frustumWriteBuffer = frustumTripleBuffer.bufferForWrite(frame: cullFrameIndex)
    let frustumWritePointer = frustumWriteBuffer.contents().bindMemory(to: simd_float4.self, capacity: planeCount)
    for i in 0 ..< planeCount {
        frustumWritePointer[i] = simd_float4(frustum.planes[i].n, frustum.planes[i].d)
    }

    let frustumReadBuffer = frustumTripleBuffer.bufferForRead(frame: cullFrameIndex)
    computeEncoder.setBuffer(frustumReadBuffer, offset: 0, index: Int(frustumCullingPassPlanesIndex.rawValue))

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

    var entityAABBContainer: [EntityAABB] = []

    for entityId in entities {
        guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
            handleError(.noRenderComponent, entityId)
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

        if hasComponent(entityId: entityId, componentType: LightComponent.self) {
            continue
        }

        // get object AABB
        let entityAABB: EntityAABB = makeObjectAABB(localMin: localTransformComponent.boundingBox.min, localMax: localTransformComponent.boundingBox.max, worldMatrix: worldTransformComponent.space, index: getEntityIndex(entityId), version: getEntityVersion(entityId))

        entityAABBContainer.append(entityAABB)
    }

    // ensure we have enough capacity

    let count = entityAABBContainer.count
    entityAABBTripleBuffer.ensureCapacity(count)

    // write current frame's data
    let entityAABBWriteBuffer = entityAABBTripleBuffer.bufferForWrite(frame: cullFrameIndex)

    entityAABBContainer.withUnsafeBytes { src in

        entityAABBWriteBuffer.contents().copyMemory(from: src.baseAddress!, byteCount: src.count)
    }

    // pick the buffer the gpu should read
    let entityAABBReadBuffer = entityAABBTripleBuffer.bufferForRead(frame: cullFrameIndex)

    computeEncoder.setBuffer(entityAABBReadBuffer, offset: 0, index: Int(frustumCullingPassObjectIndex.rawValue))

    var count32 = UInt32(count)
    computeEncoder.setBytes(&count32, length: MemoryLayout<UInt32>.stride, index: Int(frustumCullingPassObjectCountIndex.rawValue))

    computeEncoder.setBuffer(bufferResources.visibleCountBuffer, offset: 0, index: Int(frustumCullingPassVisibleCountIndex.rawValue))

    computeEncoder.setBuffer(bufferResources.visibilityBuffer, offset: 0, index: Int(frustumCullingPassVisibilityIndex.rawValue))

    guard count > 0 else {
        computeEncoder.endEncoding()
        return
    }

    let tew = frustumCullingPipeline.pipelineState?.threadExecutionWidth // e.g. 32/64
    let maxT = frustumCullingPipeline.pipelineState?.maxTotalThreadsPerThreadgroup // device cap
    let target = 256
    var block = min(target, maxT!)
    block = (block / tew!) * tew! // align down to multiple of tew
    block = max(block, tew!) // never below tew

    let threadsPerThreadgroup: MTLSize = MTLSizeMake(block, 1, 1)
    let threadsPerGrid: MTLSize = MTLSizeMake(count, 1, 1)

    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

    /*
     let numThreadgroups = (N + block - 1) / block
     computeEncoder.dispatchThreadgroups(MTLSize(width: numThreadgroups, height: 1, depth: 1),
                                         threadsPerThreadgroup: MTLSize(width: block, height: 1, depth: 1))
     */
    computeEncoder.endEncoding()

    commandBuffer.addCompletedHandler { _ in
        let visibleCount = visibilityCountBuffer.contents().load(as: UInt32.self)
        let visibleEntities = visibilityBuffer.contents().bindMemory(to: VisibleEntity.self, capacity: Int(visibleCount))

        var nextVisibleIds: [EntityID] = []
        for i in 0 ..< Int(visibleCount) {
            let index = visibleEntities[i].index
            let version = visibleEntities[i].version
            nextVisibleIds.append(createEntityId(EntityIndex(index), EntityVersion(version)))
        }
        
        // Swap into the write slot on the render thread
        DispatchQueue.main.async{
            tripleVisibleEntities.setWrite(frame: cullFrameIndex, with: nextVisibleIds)
            cullFrameIndex += 1
        }
    }
}
