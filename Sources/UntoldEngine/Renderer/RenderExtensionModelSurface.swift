//
//  RenderExtensionModelSurface.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd

public typealias RenderModelSurfaceEntityBinding = (
    _ encoder: MTLRenderCommandEncoder,
    _ entityId: EntityID,
    _ resources: RenderResourceAccess
) -> Void

public enum RenderExtensionModelSurfaceSlot {
    public static let fragmentBuffer0 = 10
    public static let fragmentBuffer1 = 11
    public static let fragmentBuffer2 = 12
    public static let fragmentBuffer3 = 13

    public static let fragmentTexture0 = 10
    public static let fragmentTexture1 = 11
    public static let fragmentTexture2 = 12
    public static let fragmentTexture3 = 13
}

public extension RenderPassContext {
    func drawModelSurfaceEntities(
        pipeline pipelineType: RenderPipelineType,
        matching componentTypes: [any Component.Type] = [],
        label: String = "Render Extension Model Surface",
        bindEntity: RenderModelSurfaceEntityBinding? = nil
    ) {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[pipelineType],
              pipeline.success,
              let pipelineState = pipeline.pipelineState
        else {
            Logger.logWarning(message: "[RenderExtension] Model surface pipeline '\(pipelineType.rawValue)' is not available")
            return
        }

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = getEntityComponent(entityId: camera, componentType: CameraComponent.self)
        else {
            handleError(.noActiveCamera)
            return
        }

        guard let descriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, label)
            return
        }

        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.depthAttachment.loadAction = .load
        descriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            handleError(.renderPassCreationFailed, label)
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = label
        renderEncoder.pushDebugGroup(label)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(pipeline.depthState)

        let requiredComponents = modelSurfaceRequiredComponents(componentTypes)
        let visibleEntities = Set(visibleEntityIds)
        let entities = queryEntities(with: requiredComponents)

        for entityId in entities where visibleEntities.contains(entityId) {
            guard shouldDrawModelSurfaceEntity(entityId) else { continue }

            guard let renderComponent = getEntityComponent(entityId: entityId, componentType: RenderComponent.self),
                  renderComponent.isVisible,
                  let worldTransform = getEntityComponent(entityId: entityId, componentType: WorldTransformComponent.self)
            else {
                continue
            }

            bindEntity?(renderEncoder, entityId, resources)
            drawModelSurfaceMeshes(
                renderComponent.mesh,
                entityId: entityId,
                worldTransform: worldTransform,
                cameraComponent: cameraComponent,
                renderEncoder: renderEncoder
            )
        }
    }
}

private func modelSurfaceRequiredComponents(
    _ componentTypes: [any Component.Type]
) -> [any Component.Type] {
    var result = componentTypes
    var seen = Set(componentTypes.map { ObjectIdentifier($0) })

    for componentType in [RenderComponent.self, WorldTransformComponent.self] as [any Component.Type] {
        let id = ObjectIdentifier(componentType)
        if seen.insert(id).inserted {
            result.append(componentType)
        }
    }

    return result
}

private func shouldDrawModelSurfaceEntity(_ entityId: EntityID) -> Bool {
    if scene.mask(for: entityId) == nil { return false }
    if shouldHideSceneEntity(entityId: entityId) { return false }
    if BatchingSystem.shared.isEnabled(), BatchingSystem.shared.isBatched(entityId: entityId) { return false }
    if hasComponent(entityId: entityId, componentType: GizmoComponent.self) { return false }
    if hasComponent(entityId: entityId, componentType: LightComponent.self) { return false }
    if hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) { return false }
    if hasComponent(entityId: entityId, componentType: CameraComponent.self) { return false }
    return true
}

private func drawModelSurfaceMeshes(
    _ meshes: [Mesh],
    entityId: EntityID,
    worldTransform: WorldTransformComponent,
    cameraComponent: CameraComponent,
    renderEncoder: MTLRenderCommandEncoder
) {
    for mesh in meshes {
        guard mesh.metalKitMesh.vertexBuffers.count > Int(modelPassJointWeightsIndex.rawValue) else {
            continue
        }

        var uniforms = Uniforms()
        let modelMatrix = simd_mul(worldTransform.space, mesh.localSpace)
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
        let normalMatrix = upperModelMatrix.inverse.transpose

        uniforms.modelViewMatrix = modelViewMatrix
        uniforms.normalMatrix = normalMatrix
        uniforms.viewMatrix = viewMatrix
        uniforms.modelMatrix = modelMatrix
        uniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        uniforms.projectionMatrix = renderInfo.perspectiveSpace

        renderEncoder.setVertexBytes(
            &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            index: Int(modelPassUniformIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            index: Int(modelPassFragmentUniformIndex.rawValue)
        )

        let jointTransformBuffer = mesh.skin?.jointTransformsBuffer
        var hasArmature = getEntityComponent(entityId: entityId, componentType: SkeletonComponent.self) != nil && jointTransformBuffer != nil
        renderEncoder.setVertexBytes(
            &hasArmature,
            length: MemoryLayout<Bool>.stride,
            index: Int(modelPassHasArmature.rawValue)
        )

        renderEncoder.setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassVerticesIndex.rawValue)
        )
        renderEncoder.setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassNormalIndex.rawValue)
        )
        renderEncoder.setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassUVIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassUVIndex.rawValue)
        )
        renderEncoder.setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassTangentIndex.rawValue)
        )
        renderEncoder.setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassJointIdIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassJointIdIndex.rawValue)
        )
        renderEncoder.setVertexBuffer(
            mesh.metalKitMesh.vertexBuffers[Int(modelPassJointWeightsIndex.rawValue)].buffer,
            offset: 0,
            index: Int(modelPassJointWeightsIndex.rawValue)
        )

        if let jointTransformBuffer {
            renderEncoder.setVertexBuffer(
                jointTransformBuffer,
                offset: 0,
                index: Int(modelPassJointTransformIndex.rawValue)
            )
        } else {
            var identityMatrix = matrix_identity_float4x4
            renderEncoder.setVertexBytes(
                &identityMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: Int(modelPassJointTransformIndex.rawValue)
            )
        }

        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitivesTracked(
                type: submesh.metalKitSubmesh.primitiveType,
                indexCount: submesh.metalKitSubmesh.indexCount,
                indexType: submesh.metalKitSubmesh.indexType,
                indexBuffer: submesh.metalKitSubmesh.indexBuffer.buffer,
                indexBufferOffset: submesh.metalKitSubmesh.indexBuffer.offset,
                category: .other
            )
        }
    }
}
