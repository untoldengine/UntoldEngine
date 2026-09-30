//
//  MeshQuery.swift
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

/// The rest geometry of one material slot of an entity's mesh, as the
/// vertex buffers hold it: positions and normals in the mesh's space, the
/// slot's triangles as indices into the mesh's vertex buffer, and the skin
/// binding of every vertex (skeleton joint indices and weights, four per
/// vertex; empty for unskinned meshes).
public struct EntitySubmeshGeometry: Sendable {
    /// Vertex count of the whole mesh (indices address it).
    public var meshVertexCount: Int
    public var positions: [simd_float3]
    public var normals: [simd_float3]
    /// Triangle list, three vertex indices per triangle.
    public var triangles: [UInt32]
    /// Skeleton joint indices per vertex (`entitySkeletonJointPoses` order).
    public var jointIndices: [simd_ushort4]
    public var jointWeights: [simd_float4]
    /// The mesh's local transform (applied before the entity's).
    public var localTransform: simd_float4x4
}

/// Reads the rest geometry of `submeshIndex` of `meshIndex` on `entityId`
/// (or the first descendant carrying the mesh, for a character root).
/// Vertex buffers are read back on the CPU; nil when the mesh or slot does
/// not exist or its buffers are not CPU-readable.
public func entitySubmeshGeometry(entityId: EntityID, meshIndex: Int, submeshIndex: Int) -> EntitySubmeshGeometry? {
    guard scene.exists(entityId),
          let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
          renderComponent.mesh.indices.contains(meshIndex)
    else { return nil }
    let mesh = renderComponent.mesh[meshIndex]
    guard mesh.submeshes.indices.contains(submeshIndex) else { return nil }
    let mtk = mesh.metalKitMesh
    let vertexCount = mtk.vertexCount
    guard vertexCount > 0, mtk.vertexBuffers.count > Int(modelPassJointWeightsIndex.rawValue) else { return nil }

    func read<T>(_ slot: Int, as _: T.Type) -> [T]? {
        let buffer = mtk.vertexBuffers[slot]
        guard buffer.buffer.storageMode != .private else { return nil }
        let pointer = buffer.buffer.contents().advanced(by: buffer.offset).bindMemory(to: T.self, capacity: vertexCount)
        return Array(UnsafeBufferPointer(start: pointer, count: vertexCount))
    }
    guard let positions4 = read(Int(modelPassVerticesIndex.rawValue), as: simd_float4.self),
          let normals4 = read(Int(modelPassNormalIndex.rawValue), as: simd_float4.self)
    else { return nil }
    let jointIndices = mesh.skin != nil ? read(Int(modelPassJointIdIndex.rawValue), as: simd_ushort4.self) ?? [] : []
    let jointWeights = mesh.skin != nil ? read(Int(modelPassJointWeightsIndex.rawValue), as: simd_float4.self) ?? [] : []

    let submesh = mesh.submeshes[submeshIndex].metalKitSubmesh
    let indexBuffer = submesh.indexBuffer
    guard indexBuffer.buffer.storageMode != .private else { return nil }
    let indexBase = indexBuffer.buffer.contents().advanced(by: indexBuffer.offset)
    var triangles = [UInt32](repeating: 0, count: submesh.indexCount)
    switch submesh.indexType {
    case .uint16:
        let pointer = indexBase.bindMemory(to: UInt16.self, capacity: submesh.indexCount)
        for i in 0 ..< submesh.indexCount {
            triangles[i] = UInt32(pointer[i])
        }
    case .uint32:
        let pointer = indexBase.bindMemory(to: UInt32.self, capacity: submesh.indexCount)
        for i in 0 ..< submesh.indexCount {
            triangles[i] = pointer[i]
        }
    @unknown default:
        return nil
    }

    // Skin joint ids index the skin's joint list; report skeleton joints.
    let map = mesh.skin?.skinToSkeletonMap ?? []
    let skeletonJointIndices: [simd_ushort4] = jointIndices.map { ids in
        func remap(_ id: UInt16) -> UInt16 {
            let i = Int(id)
            return map.indices.contains(i) ? UInt16(clamping: map[i]) : id
        }
        return simd_ushort4(remap(ids.x), remap(ids.y), remap(ids.z), remap(ids.w))
    }

    return EntitySubmeshGeometry(
        meshVertexCount: vertexCount,
        positions: positions4.map { simd_float3($0.x, $0.y, $0.z) },
        normals: normals4.map { simd_float3($0.x, $0.y, $0.z) },
        triangles: triangles,
        jointIndices: skeletonJointIndices,
        jointWeights: jointWeights,
        localTransform: mesh.localSpace
    )
}

/// Supplies the deformed position and normal of some vertices of mesh
/// `meshIndex` on `entityId` from outside (a cloth simulation owning a
/// cape, say): written over the deformation pass's output every frame
/// until cleared, in the mesh's space. The entity must be on a compute
/// skinning path (`DeformationComponent`). Call once per frame from any
/// thread; `positions`, `normals` and `indices` run in parallel.
public func setEntityDeformationOverride(
    entityId: EntityID, meshIndex: Int,
    indices: [UInt32], positions: [simd_float3], normals: [simd_float3]
) {
    guard scene.exists(entityId),
          let component = scene.get(component: DeformationComponent.self, for: entityId),
          let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
          renderComponent.mesh.indices.contains(meshIndex),
          !indices.isEmpty
    else { return }
    let mesh = renderComponent.mesh[meshIndex]
    let key = ObjectIdentifier(mesh.metalKitMesh)
    component.meshOverrideLock.withLock {
        var override = component.meshOverrides[key]
        if override == nil || override!.capacity < indices.count {
            override = MeshDeformationOverride(
                device: renderInfo.device, capacity: max(indices.count, mesh.metalKitMesh.vertexCount), label: mesh.name
            )
            component.meshOverrides[key] = override
        }
        override?.write(indices: indices, positions: positions, normals: normals)
    }
}

/// Stops overriding mesh `meshIndex` of `entityId`.
public func clearEntityDeformationOverride(entityId: EntityID, meshIndex: Int) {
    guard scene.exists(entityId),
          let component = scene.get(component: DeformationComponent.self, for: entityId),
          let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
          renderComponent.mesh.indices.contains(meshIndex)
    else { return }
    let key = ObjectIdentifier(renderComponent.mesh[meshIndex].metalKitMesh)
    component.meshOverrideLock.withLock { component.meshOverrides[key] = nil }
}
