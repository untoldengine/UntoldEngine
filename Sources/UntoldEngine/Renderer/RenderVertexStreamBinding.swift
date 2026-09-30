
//
//  RenderVertexStreamBinding.swift
//  UntoldEngine
//
//  Shared per-mesh vertex-stream binding for the model-family and shadow-family
//  render passes.
//

import CShaderTypes
import Metal
import MetalKit
import simd

/// Mesh.metalKitMesh.vertexBuffers is laid out in model-descriptor order
/// (ModelPassBufferIndices 0-5) regardless of which pass consumes it; the
/// shadow pass sources from that same array but binds to its own slots.
/// When the deformation compute pass has produced deformed streams for the
/// mesh (see `DeformationSystem`), those replace the base position, normal,
/// and tangent buffers and vertex-shader skinning is disabled.
extension MTLRenderCommandEncoder {
    func bindModelVertexStreams(mesh: Mesh, entityId: EntityID) {
        let deformed = deformedStreams(mesh: mesh, entityId: entityId)

        setVertexBuffer(
            deformed?.positions ?? mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassVerticesIndex.rawValue)
        )
        setVertexBuffer(
            deformed?.normals ?? mesh.metalKitMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassNormalIndex.rawValue)
        )
        setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassUVIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassUVIndex.rawValue)
        )
        setVertexBuffer(
            deformed?.tangents ?? mesh.metalKitMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassTangentIndex.rawValue)
        )
        setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassJointIdIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassJointIdIndex.rawValue)
        )
        setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassJointWeightsIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassJointWeightsIndex.rawValue)
        )
        bindJointStreams(
            mesh: mesh,
            entityId: entityId,
            skinnedInCompute: deformed != nil,
            hasArmatureIndex: Int(modelPassHasArmature.rawValue),
            jointTransformIndex: Int(modelPassJointTransformIndex.rawValue)
        )
    }

    func bindShadowVertexStreams(mesh: Mesh, entityId: EntityID) {
        let deformed = deformedStreams(mesh: mesh, entityId: entityId)

        setVertexBuffer(
            deformed?.positions ?? mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
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
            skinnedInCompute: deformed != nil,
            hasArmatureIndex: Int(shadowPassHasArmature.rawValue),
            jointTransformIndex: Int(shadowPassJointTransformIndex.rawValue)
        )
    }

    /// Deformed streams exist only after the deformation pass has run for
    /// this mesh; until then (or without a DeformationComponent) draws use
    /// the base streams and vertex-shader skinning.
    private func deformedStreams(mesh: Mesh, entityId: EntityID) -> MeshDeformationBuffers? {
        guard let component = getEntityComponent(entityId: entityId, componentType: DeformationComponent.self) else {
            return nil
        }
        return component.meshDeformations[ObjectIdentifier(mesh.metalKitMesh)]
    }

    private func bindJointStreams(
        mesh: Mesh,
        entityId: EntityID,
        skinnedInCompute: Bool,
        hasArmatureIndex: Int,
        jointTransformIndex: Int
    ) {
        // Only enable armature path when a valid joint transform buffer
        // exists and skinning did not already happen in compute.
        let jointTransformBuffer = mesh.skin?.jointTransformsBuffer
        var hasArmature = !skinnedInCompute
            && getEntityComponent(entityId: entityId, componentType: SkeletonComponent.self) != nil
            && jointTransformBuffer != nil
        setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: hasArmatureIndex)

        if hasArmature, let jointTransformBuffer {
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
