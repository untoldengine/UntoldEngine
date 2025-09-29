//
//  RenderPasses.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 29/9/25.
//

import Foundation
import UntoldEngine
import MetalKit
import CShaderTypes


extension RenderPasses
{
    static let gizmoExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if activeEntity == .invalid {
            return
        }
        
        guard let gizmoPipeline = PipelineManager.shared.renderPipelinesByType[ .gizmo ] else {
            handleError(.pipelineStateNulled, "gizmoPipeline is nil")
            return
        }

        if gizmoPipeline.success == false {
            handleError(.pipelineStateNulled, gizmoPipeline.name!)
            return
        }
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
            handleError(.noActiveCamera)
            return
        }
        renderInfo.gizmoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .load

        renderInfo.gizmoRenderPassDescriptor.depthAttachment.loadAction = .clear

        let encoderDescriptor = renderInfo.gizmoRenderPassDescriptor!

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Gizmo Pass")

            return
        }

        renderEncoder.label = "Gizmo Pass"

        renderEncoder.pushDebugGroup("Gizmo Pass")

        renderEncoder.setRenderPipelineState(gizmoPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(gizmoPipeline.depthState)
        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.0)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        // Create a component query for entities with both Transform and Render components

        let transformId = getComponentId(for: WorldTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let gizmoId = getComponentId(for: GizmoComponent.self)

        let entities = queryEntitiesWithComponentIds([transformId, renderId, gizmoId], in: scene)

        // Iterate over the entities found by the component query
        for entityId in entities {
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
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

            let distanceToCamera = length(getCameraPosition(entityId: getMainCamera()) - getPosition(entityId: parentEntityIdGizmo))

            let worldScale = (distanceToCamera * tan(fov * 0.5)) * (gizmoDesiredScreenSize / renderInfo.viewPort.y)

            localTransformComponent.scale = simd_float3(repeating: worldScale)
            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)

                let viewMatrix: simd_float4x4 = cameraComponent.viewSpace

                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

                let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

                let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

                let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

                modelUniforms.modelViewMatrix = modelViewMatrix

                modelUniforms.normalMatrix = normalMatrix

                modelUniforms.viewMatrix = viewMatrix

                modelUniforms.modelMatrix = modelMatrix

                modelUniforms.cameraPosition = cameraComponent.localPosition

                modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                if let modelUniformBuffer = mesh.spaceUniform {
                    modelUniformBuffer.contents().copyMemory(
                        from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride
                    )
                } else {
                    handleError(.bufferAllocationFailed, "Gizmo Uniform buffer")
                    return
                }

                renderEncoder.setVertexBuffer(
                    mesh.spaceUniform, offset: 0, index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.setFragmentBuffer(
                    mesh.spaceUniform, offset: 0, index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassVerticesIndex.rawValue)
                )

                for subMesh in mesh.submeshes {
                    var materialParameters = MaterialParametersUniform()
                    materialParameters.specular = subMesh.material!.specular
                    materialParameters.specularTint = subMesh.material!.specularTint
                    materialParameters.subsurface = subMesh.material!.subsurface
                    materialParameters.anisotropic = subMesh.material!.anisotropic
                    materialParameters.sheen = subMesh.material!.sheen
                    materialParameters.sheenTint = subMesh.material!.sheenTint
                    materialParameters.clearCoat = subMesh.material!.clearCoat
                    materialParameters.clearCoatGloss = subMesh.material!.clearCoatGloss
                    materialParameters.baseColor = subMesh.material!.baseColorValue
                    materialParameters.roughness = subMesh.material!.roughnessValue
                    materialParameters.metallic = subMesh.material!.metallicValue
                    materialParameters.ior = subMesh.material!.ior
                    materialParameters.edgeTint = subMesh.material!.edgeTint
                    materialParameters.interactWithLight = subMesh.material!.interactWithLight
                    materialParameters.emmissive = subMesh.material!.emissiveValue

                    renderEncoder.setFragmentBytes(
                        &materialParameters, length: MemoryLayout<MaterialParametersUniform>.stride,
                        index: Int(modelPassFragmentMaterialParameterIndex.rawValue)
                    )

                    renderEncoder.drawIndexedPrimitives(
                        type: subMesh.metalKitSubmesh.primitiveType,
                        indexCount: subMesh.metalKitSubmesh.indexCount,
                        indexType: subMesh.metalKitSubmesh.indexType,
                        indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                        indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset
                    )
                }
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static let outlineExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if activeEntity == .invalid {
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        guard let outlinePipeline = PipelineManager.shared.renderPipelinesByType[ .outline ] else {
            handleError(.pipelineStateNulled, "outlinePipeline is nil")
            return
        }
        
        if outlinePipeline.success == false {
            handleError(.pipelineStateNulled, outlinePipeline.name!)
            return
        }

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .loadAction = .load

        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load

        let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor!

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Outline Pass")

            return
        }

        renderEncoder.label = "Outline Pass"

        renderEncoder.pushDebugGroup("Outline Pass")

        renderEncoder.setRenderPipelineState(outlinePipeline.pipelineState!)

        renderEncoder.setDepthStencilState(outlinePipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setCullMode(.front)

        renderEncoder.setFrontFacing(.counterClockwise)

        // Send model info to outline here
        if let renderComponent = scene.get(component: RenderComponent.self, for: activeEntity), scene.get(component: LightComponent.self, for: activeEntity) == nil {
            let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: activeEntity)

            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(worldTransformComponent!.space, mesh.localSpace)

                let viewMatrix: simd_float4x4 = cameraComponent.viewSpace

                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

                let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

                let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

                let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

                modelUniforms.modelViewMatrix = modelViewMatrix

                modelUniforms.normalMatrix = normalMatrix

                modelUniforms.viewMatrix = viewMatrix

                modelUniforms.modelMatrix = modelMatrix

                modelUniforms.cameraPosition = cameraComponent.localPosition

                modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                if let modelUniformBuffer = mesh.spaceUniform {
                    modelUniformBuffer.contents().copyMemory(
                        from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride
                    )
                } else {
                    handleError(.bufferAllocationFailed, "Model Uniform buffer")
                    return
                }

                renderEncoder.setVertexBuffer(
                    mesh.spaceUniform, offset: 0, index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.setFragmentBuffer(
                    mesh.spaceUniform, offset: 0, index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassVerticesIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassVerticesIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassNormalIndex.rawValue)
                )

                for subMesh in mesh.submeshes {
                    renderEncoder.drawIndexedPrimitives(
                        type: subMesh.metalKitSubmesh.primitiveType,
                        indexCount: subMesh.metalKitSubmesh.indexCount,
                        indexType: subMesh.metalKitSubmesh.indexType,
                        indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                        indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset
                    )
                }
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
    
    static let debuggerExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        guard let debuggerPipeline = PipelineManager.shared.renderPipelinesByType[ .lightVisual ] else {
            handleError(.pipelineStateNulled, "debuggerPipeline is nil")
            return
        }
        
        if !debuggerPipeline.success {
            handleError(.pipelineStateNulled, debuggerPipeline.name!)
            return
        }

        let renderPassDescriptor = renderInfo.renderPassDescriptor!

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = MTLLoadAction.load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .loadAction = .load

        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .clear

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Debugger Pass")
            return
        }

        renderEncoder.label = "Debugger Pass"

        renderEncoder.pushDebugGroup("Debugger Pass")

        renderEncoder.setRenderPipelineState(debuggerPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(debuggerPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        let selectedTextureName = DebugSettings.shared.selectedName

        if let debugTexture = DebugTextureRegistry.get(byName: selectedTextureName) {
            renderEncoder.setFragmentTexture(debugTexture, index: 0)
        }

        var isDepthTexture = false
        if selectedTextureName == "Depth Texture" {
            isDepthTexture = true
        }

        var farnear = simd_float2(near, far)
        renderEncoder.setFragmentTexture(textureResources.depthMap, index: 1)
        renderEncoder.setFragmentBytes(&isDepthTexture, length: MemoryLayout<Bool>.stride, index: 0)
        renderEncoder.setFragmentBytes(&farnear, length: MemoryLayout<simd_float2>.stride, index: 1)

        // set the draw command
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
    
    static let lightVisualPass: (MTLCommandBuffer) -> Void = { commandBuffer in

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        guard let lightVisualPipeline = PipelineManager.shared.renderPipelinesByType[ .lightVisual ] else {
            handleError(.pipelineStateNulled, "lightVisualPipeline is nil")
            return
        }
        
        if lightVisualPipeline.success == false {
            handleError(.pipelineStateNulled, lightVisualPipeline.name!)
            return
        }

        renderInfo.gizmoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .load

        renderInfo.gizmoRenderPassDescriptor.depthAttachment.loadAction = .load

        let encoderDescriptor = renderInfo.gizmoRenderPassDescriptor!

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Light Visual Pass")

            return
        }

        renderEncoder.label = "Light Visual Pass"

        renderEncoder.pushDebugGroup("Light Visual Pass")

        renderEncoder.setRenderPipelineState(lightVisualPipeline.pipelineState!)

        renderEncoder.setDepthStencilState(lightVisualPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.counterClockwise)

        let transformId = getComponentId(for: LocalTransformComponent.self)
        let lightId = getComponentId(for: LightComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, lightId], in: scene)

        // Iterate over the entities found by the component query
        for entityId in entities {
            guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                handleError(.noLocalTransformComponent, entityId)
                continue
            }

            guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                handleError(.noLightComponent, entityId)
                continue
            }

            renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

            renderEncoder.setVertexBytes(
                &cameraComponent.viewSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 2
            )

            renderEncoder.setVertexBytes(
                &renderInfo.perspectiveSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 3
            )

            renderEncoder.setVertexBytes(
                &localTransformComponent.space, length: MemoryLayout<matrix_float4x4>.stride, index: 4
            )

            switch lightComponent.lightType {
            case .directional:
                renderEncoder.setFragmentTexture(lightComponent.texture.directional, index: 0)
            case .point:
                renderEncoder.setFragmentTexture(lightComponent.texture.point, index: 0)
            case .spotlight:
                renderEncoder.setFragmentTexture(lightComponent.texture.spot, index: 0)
            case .area:
                renderEncoder.setFragmentTexture(lightComponent.texture.area, index: 0)
            default:
                break
            }

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: quadIndices.count,
                                                indexType: .uint16,
                                                indexBuffer: bufferResources.quadIndexBuffer!,
                                                indexBufferOffset: 0)
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
    
    static let highlightExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if activeEntity == .invalid {
            renderInfo.gizmoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
                .loadAction = .clear

            renderInfo.gizmoRenderPassDescriptor.depthAttachment.loadAction = .clear

            let encoderDescriptor = renderInfo.gizmoRenderPassDescriptor!

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
            else {
                handleError(.renderPassCreationFailed, "Highlight Pass")

                return
            }

            renderEncoder.label = "Highlight Pass"

            renderEncoder.pushDebugGroup("Highlight Pass")

            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()

            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        guard let hightlightPipeline = PipelineManager.shared.renderPipelinesByType[ .highlight ] else {
            handleError(.pipelineStateNulled, "highlightPipeline is nil")
            return
        }
        
        if hightlightPipeline.success == false {
            handleError(.pipelineStateNulled, hightlightPipeline.name!)
            return
        }

        renderInfo.gizmoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .clear

        renderInfo.gizmoRenderPassDescriptor.depthAttachment.loadAction = .clear

        let encoderDescriptor = renderInfo.gizmoRenderPassDescriptor!

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Highlight Pass")

            return
        }

        renderEncoder.label = "Highlight Pass"

        renderEncoder.pushDebugGroup("Highlight Pass")

        renderEncoder.setRenderPipelineState(hightlightPipeline.pipelineState!)

        renderEncoder.setDepthStencilState(hightlightPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.counterClockwise)

        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: activeEntity) else {
            handleError(.noWorldTransformComponent)
            return
        }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: activeEntity) else {
            handleError(.noRenderComponent)
            return
        }

        renderEncoder.setVertexBytes(
            &cameraComponent.viewSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 1
        )

        renderEncoder.setVertexBytes(
            &renderInfo.perspectiveSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 2
        )

        renderEncoder.setVertexBytes(
            &worldTransform.space, length: MemoryLayout<matrix_float4x4>.stride, index: 3
        )

        var scale: simd_float3 = .one

        if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
            var lightMesh: [Mesh] = []
            if let pointLightComponent = scene.get(component: PointLightComponent.self, for: activeEntity) {
                scale = simd_float3(repeating: pointLightComponent.radius)
                lightMesh = pointLightDebugMesh
            } else if let spotLightComponent = scene.get(component: SpotLightComponent.self, for: activeEntity) {
                let theta = degreesToRadians(degrees: spotLightComponent.coneAngle)
                let radius = tan(theta) * spotLightComponent.radius

                scale = simd_float3(radius, radius, spotLightComponent.radius / 2.0)
                lightMesh = spotLightDebugMesh
            } else if let areaLightComponent = scene.get(component: AreaLightComponent.self, for: activeEntity) {
                lightMesh = areaLightDebugMesh
            } else if let dirLightComponent = scene.get(component: DirectionalLightComponent.self, for: activeEntity) {
                lightMesh = dirLightDebugMesh
            }

            renderEncoder.setVertexBytes(&scale, length: MemoryLayout<simd_float3>.stride, index: 4)

            renderEncoder.setTriangleFillMode(.lines)
            for mesh in lightMesh {
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassVerticesIndex.rawValue)
                )

                for subMesh in mesh.submeshes {
                    renderEncoder.drawIndexedPrimitives(
                        type: subMesh.metalKitSubmesh.primitiveType,
                        indexCount: subMesh.metalKitSubmesh.indexCount,
                        indexType: subMesh.metalKitSubmesh.indexType,
                        indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                        indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset
                    )
                }
            }

        } else {
            scale = simd_float3(repeating: 1.2)
            renderEncoder.setVertexBytes(&scale, length: MemoryLayout<simd_float3>.stride, index: 4)
            renderEncoder.setVertexBuffer(bufferResources.boundingBoxBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: boundingBoxVertexCount)
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
}
