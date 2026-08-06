//
//  RenderVertexStreamBinding.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import MetalKit
import simd

/// Mesh.metalKitMesh.vertexBuffers is laid out in model-descriptor order
/// (ModelPassBufferIndices 0-5) regardless of which pass consumes it; the
/// shadow pass sources from that same array but binds to its own slots.
extension MTLRenderCommandEncoder {
    func bindModelVertexStreams(mesh: Mesh, entityId: EntityID) {
        let slots: [ModelPassBufferIndices] = [
            modelPassVerticesIndex,
            modelPassNormalIndex,
            modelPassUVIndex,
            modelPassTangentIndex,
            modelPassJointIdIndex,
            modelPassJointWeightsIndex,
        ]
        for slot in slots {
            setVertexBuffer(
                mesh.metalKitMesh.vertexBuffers[Int(slot.rawValue)].buffer,
                offset: 0,
                index: Int(slot.rawValue)
            )
        }
        bindJointStreams(
            mesh: mesh,
            entityId: entityId,
            hasArmatureIndex: Int(modelPassHasArmature.rawValue),
            jointTransformIndex: Int(modelPassJointTransformIndex.rawValue)
        )
    }

    func bindShadowVertexStreams(mesh: Mesh, entityId: EntityID) {
        setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
            offset: 0,
            index: Int(shadowPassModelPositionIndex.rawValue)
        )
        setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassJointIdIndex.rawValue)].buffer,
            offset: 0,
            index: Int(shadowPassJointIdIndex.rawValue)
        )
        setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassJointWeightsIndex.rawValue)].buffer,
            offset: 0,
            index: Int(shadowPassJointWeightsIndex.rawValue)
        )
        bindJointStreams(
            mesh: mesh,
            entityId: entityId,
            hasArmatureIndex: Int(shadowPassHasArmature.rawValue),
            jointTransformIndex: Int(shadowPassJointTransformIndex.rawValue)
        )
    }

    private func bindJointStreams(
        mesh: Mesh,
        entityId: EntityID,
        hasArmatureIndex: Int,
        jointTransformIndex: Int
    ) {
        // Only enable armature path when a valid joint transform buffer exists.
        let jointTransformBuffer = mesh.skin?.jointTransformsBuffer
        var hasArmature = getEntityComponent(entityId: entityId, componentType: SkeletonComponent.self) != nil
            && jointTransformBuffer != nil
        setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: hasArmatureIndex)

        if let jointTransformBuffer {
            setVertexBuffer(jointTransformBuffer, offset: 0, index: jointTransformIndex)
        } else {
            var identityMatrix = matrix_identity_float4x4
            setVertexBytes(
                &identityMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: jointTransformIndex
            )
        }
    }
}
