
//
//  RenderPasses.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
import Metal
import MetalKit

public enum RenderPasses {
    public static let gridExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let gridPipeline = PipelineManager.shared.renderPipelinesByType[.grid] else {
            handleError(.pipelineStateNulled, "gridPipeline is nil")
            return
        }

        if gridPipeline.success == false {
            handleError(.pipelineStateNulled, gridPipeline.name!)
            return
        }

        // update uniforms
        var gridUniforms = Uniforms()

        let modelMatrix = simd_float4x4.init(1.0)

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }
        var viewMatrix: simd_float4x4 = cameraComponent.viewSpace

        viewMatrix = viewMatrix.inverse
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        gridUniforms.modelViewMatrix = modelViewMatrix
        gridUniforms.viewMatrix = viewMatrix

        // Note, the perspective projection space has to be inverted to create the infinite grid
        gridUniforms.projectionMatrix = renderInfo.perspectiveSpace.inverse

        if let gridUniformBuffer = bufferResources.gridUniforms {
            gridUniformBuffer.contents().copyMemory(
                from: &gridUniforms, byteCount: MemoryLayout<Uniforms>.stride
            )
        } else {
            handleError(.bufferAllocationFailed, bufferResources.gridUniforms!.label!)
            return
        }

        // create the encoder

        guard let encoderDescriptor = renderInfo.environmentRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Environment render pass descriptor not initialized")
            return
        }
        encoderDescriptor.colorAttachments[0].clearColor = mtkBackgroundColor
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Grid Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Grid Pass"

        renderEncoder.pushDebugGroup("Grid Pass")

        renderEncoder.setRenderPipelineState(gridPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(gridPipeline.depthState)

        // send the uniforms
        renderEncoder.setVertexBuffer(
            bufferResources.gridVertexBuffer, offset: 0, index: Int(gridPassPositionIndex.rawValue)
        )

        renderEncoder.setVertexBuffer(
            bufferResources.gridUniforms, offset: 0, index: Int(gridPassUniformIndex.rawValue)
        )

        renderEncoder.setFragmentBuffer(
            bufferResources.gridUniforms, offset: 0, index: Int(gridPassUniformIndex.rawValue)
        )

        // send buffer data

        renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let executeEnvironmentPass: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let environmentPipeline = PipelineManager.shared.renderPipelinesByType[.environment] else {
            handleError(.pipelineStateNulled, "environmentPipeline is nil")
            return
        }

        if environmentPipeline.success == false {
            handleError(.pipelineStateNulled, environmentPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.environmentRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Environment render pass descriptor not initialized")
            return
        }

        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Environment Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Environment Pass"

        renderEncoder.pushDebugGroup("Environment Pass")

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.clockwise)

        renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)

        var environmentConstants = EnvironmentConstants()
        environmentConstants.modelMatrix = matrix4x4Identity()
        environmentConstants.environmentRotation = matrix4x4Identity()
        environmentConstants.projectionMatrix = renderInfo.perspectiveSpace
        environmentConstants.viewMatrix = cameraComponent.viewSpace

        // remove the translational part of the view matrix to make the environment stay "infinitely" far away
        environmentConstants.viewMatrix.columns.3 = simd_float4(0.0, 0.0, 0.0, 1.0)

        //    let viewports = drawable.views.map { $0.textureMap.viewport }
        //
        //    renderEncoder.setViewports(viewports)
        //
        //    if drawable.views.count > 1 {
        //        var viewMappings = (0..<drawable.views.count).map {
        //            MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
        //                                              renderTargetArrayIndexOffset: UInt32($0))
        //        }
        //        renderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
        //    }
        //
        for (index, element) in environmentMesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }

            if layout.stride != 0 {
                let buffer = environmentMesh.vertexBuffers[index]
                renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
            }
        }

        renderEncoder.setVertexBytes(
            &environmentConstants, length: MemoryLayout<EnvironmentConstants>.stride,
            index: Int(envPassConstantIndex.rawValue)
        )

        renderEncoder.setVertexBytes(
            &envRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(envPassRotationAngleIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(textureResources.environmentTexture, index: 0)

        for submesh in environmentMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }
    }

    public static let shadowExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let shadowPipeline = PipelineManager.shared.renderPipelinesByType[.shadow] else {
            handleError(.pipelineStateNulled, "shadowPipeline is nil")
            return
        }

        if shadowPipeline.success == false {
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }

        shadowSystem.updateViewFromSunPerspective()

        // if shadow has no dir light space matrix then no need to proceed
        guard let dirLight = shadowSystem.dirLightSpaceMatrix else { return }

        guard let shadowDescriptor = renderInfo.shadowRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Shadow render pass descriptor not initialized")
            return
        }

        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: shadowDescriptor)
        else {
            handleError(.renderPassCreationFailed, "shadow Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        renderEncoder.label = "Shadow Pass"
        renderEncoder.pushDebugGroup("Shadow Pass")
        renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(shadowPipeline.depthState!)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setDepthBias(0.005, slopeScale: 1.0, clamp: 1.0)
        renderEncoder.setViewport(
            MTLViewport(originX: 0.0, originY: 0.0, width: Double(shadowResolution.x), height: Double(shadowResolution.y), znear: 0.0, zfar: 1.0))

        // send buffer data
        renderEncoder.setVertexBytes(
            &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
            index: Int(shadowPassLightMatrixUniform.rawValue)
        )

        // need to send light ortho view matrix

        // send info for each entity that conforms to shadows

        // Create a component query for entities with both Transform and Render components

        // Iterate over the entities found by the component query
        for entityId in visibleEntityIds {
            // Skip entities that are pending destroy
            if scene.mask(for: entityId) == nil { continue }

            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { continue }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
                handleError(.noRenderComponent, entityId)
                continue
            }

            guard let transformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                handleError(.noWorldTransformComponent, entityId)
                continue
            }

            guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                handleError(.noLocalTransformComponent, entityId)
                continue
            }

            if let lightComponent = scene.get(component: LightComponent.self, for: entityId) {
                continue
            }

            if let gizmoComponent = scene.get(component: GizmoComponent.self, for: entityId) {
                continue
            }

            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)

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

                if let modelUniformBuffer = mesh.spaceUniform[renderInfo.currentEye] {
                    modelUniformBuffer.contents().copyMemory(
                        from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride
                    )
                } else {
                    handleError(.bufferAllocationFailed, "Model Uniform buffer")
                    return
                }

                renderEncoder.setVertexBuffer(
                    mesh.spaceUniform[renderInfo.currentEye], offset: 0, index: Int(shadowPassModelUniform.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(shadowPassModelPositionIndex.rawValue)].buffer,
                    offset: 0, index: Int(shadowPassModelPositionIndex.rawValue)
                )

                // check if it has skeleton component
                var hasArmature = false

                if let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) {
                    hasArmature = true
                }

                renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(shadowPassHasArmature.rawValue))

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassJointIdIndex.rawValue)].buffer,
                    offset: 0, index: Int(shadowPassJointIdIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassJointWeightsIndex.rawValue)].buffer,
                    offset: 0, index: Int(shadowPassJointWeightsIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(mesh.skin?.jointTransformsBuffer, offset: 0, index: Int(shadowPassJointTransformIndex.rawValue))

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
    }

    public static let modelExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let modelPipeline = PipelineManager.shared.renderPipelinesByType[.model] else {
            handleError(.pipelineStateNulled, "modelPipeline is nil")
            return
        }

        if modelPipeline.success == false {
            handleError(.pipelineStateNulled, modelPipeline.name!)
            return
        }
        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Offscreen render pass descriptor not initialized")
            return
        }

        encoderDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .clear
        encoderDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .loadAction = .clear
        encoderDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .loadAction = .clear
        encoderDescriptor.colorAttachments[Int(materialTarget.rawValue)].loadAction = .clear
        encoderDescriptor.colorAttachments[Int(emissiveTarget.rawValue)].loadAction = .clear

        encoderDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .storeAction = .store

        encoderDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .storeAction = .store
        encoderDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .storeAction = .store
        encoderDescriptor.colorAttachments[Int(materialTarget.rawValue)]
            .storeAction = .store
        encoderDescriptor.colorAttachments[Int(emissiveTarget.rawValue)]
            .storeAction = .store

        encoderDescriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Model Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Model Pass"

        renderEncoder.pushDebugGroup("Model Pass")

        renderEncoder.setRenderPipelineState(modelPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(modelPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        // Create a component query for entities with both Transform and Render components

        // Iterate over the entities found by the component query
        for entityId in visibleEntityIds {
            // Skip entities that are pending destroy
            if scene.mask(for: entityId) == nil { continue }

            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { continue }

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

            if hasComponent(entityId: entityId, componentType: GizmoComponent.self) {
                continue
            }

            if hasComponent(entityId: entityId, componentType: LightComponent.self) {
                continue
            }

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

                if let modelUniformBuffer = mesh.spaceUniform[renderInfo.currentEye] {
                    modelUniformBuffer.contents().copyMemory(
                        from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride
                    )
                } else {
                    handleError(.bufferAllocationFailed, "Model Uniform buffer")
                    return
                }

                renderEncoder.setVertexBuffer(
                    mesh.spaceUniform[renderInfo.currentEye], offset: 0, index: Int(modelPassUniformIndex.rawValue)
                )

                // check if it has skeleton component
                var hasArmature = false

                if let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) {
                    hasArmature = true
                }

                renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(modelPassHasArmature.rawValue))

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassVerticesIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassNormalIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassUVIndex.rawValue)].buffer, offset: 0,
                    index: Int(modelPassUVIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassTangentIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassJointIdIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassJointIdIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(modelPassJointWeightsIndex.rawValue)].buffer,
                    offset: 0, index: Int(modelPassJointWeightsIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(mesh.skin?.jointTransformsBuffer, offset: 0, index: Int(modelPassJointTransformIndex.rawValue))

                renderEncoder.setFragmentBuffer(
                    mesh.spaceUniform[renderInfo.currentEye], offset: 0, index: Int(modelPassFragmentUniformIndex.rawValue)
                )

                for subMesh in mesh.submeshes {
                    var stScale: Float = subMesh.material!.stScale

                    renderEncoder.setFragmentBytes(&stScale, length: MemoryLayout<Float>.stride, index: Int(modelPassFragmentSTScaleIndex.rawValue))

                    // set base texture
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.baseColor.texture, index: Int(modelPassBaseTextureIndex.rawValue)
                    )

                    renderEncoder.setFragmentSamplerState(subMesh.material?.baseColor.sampler, index: Int(modelPassBaseSamplerIndex.rawValue))

                    // set roughness
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.roughness.texture, index: Int(modelPassRoughnessTextureIndex.rawValue)
                    )

                    renderEncoder.setFragmentSamplerState(subMesh.material?.roughness.sampler, index: Int(modelPassMaterialSamplerIndex.rawValue))

                    // set normal
                    var hasNormal: Bool = ((subMesh.material?.normal.texture) != nil)
                    renderEncoder.setFragmentBytes(
                        &hasNormal, length: MemoryLayout<Bool>.stride,
                        index: Int(modelPassFragmentHasNormalTextureIndex.rawValue)
                    )

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

                    materialParameters.hasTexture = simd_int4(
                        Int32(subMesh.material!.hasBaseMap == true ? 1 : 0),
                        Int32(subMesh.material!.hasRoughMap == true ? 1 : 0),
                        Int32(subMesh.material!.hasMetalMap == true ? 1 : 0),
                        0
                    )

                    renderEncoder.setFragmentBytes(
                        &materialParameters, length: MemoryLayout<MaterialParametersUniform>.stride,
                        index: Int(modelPassFragmentMaterialParameterIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        subMesh.material?.normal.texture, index: Int(modelPassNormalTextureIndex.rawValue)
                    )

                    renderEncoder.setFragmentSamplerState(subMesh.material?.normal.sampler, index: Int(modelPassNormalSamplerIndex.rawValue))

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
    }

    static let ssaoExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let ssaoPipeline = PipelineManager.shared.renderPipelinesByType[.ssao] else {
            handleError(.pipelineStateNulled, "ssaoPipeline is nil")
            return
        }

        if !ssaoPipeline.success {
            handleError(.pipelineStateNulled, ssaoPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO render pass descriptor not initialized")
            return
        }

        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .loadAction = .load

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.ssaoRenderPassDescriptor.depthAttachment.loadAction = .clear
        renderInfo.ssaoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].storeAction = .store

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "SSAO Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Pass"

        renderEncoder.pushDebugGroup("SSAO Pass")

        renderEncoder.setRenderPipelineState(ssaoPipeline.pipelineState!)
        // renderEncoder.setDepthStencilState(ssaoPipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // pass gbufer resources
        renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture, index: Int(ssaoNormalMapTextureIndex.rawValue))

        renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture, index: Int(ssaoPositionMapTextureIndex.rawValue))

        // pass ssao resources

        if let kernelBuffer = bufferResources.ssaoKernelBuffer {
            renderEncoder.setFragmentBuffer(kernelBuffer, offset: 0, index: Int(ssaoPassKernelIndex.rawValue))
        }

        renderEncoder.setFragmentTexture(textureResources.ssaoNoiseTexture, index: Int(ssaoNoiseMapTextureIndex.rawValue))

        renderEncoder.setFragmentBytes(&ssaoKernelSize, length: MemoryLayout<Int>.stride, index: Int(ssaoPassKernelSizeIndex.rawValue))

        renderEncoder.setFragmentBytes(&renderInfo.viewPort, length: MemoryLayout<simd_float2>.stride, index: Int(ssaoPassViewPortIndex.rawValue))

        renderEncoder.setFragmentBytes(&renderInfo.perspectiveSpace, length: MemoryLayout<simd_float4x4>.stride, index: Int(ssaoPassPerspectiveSpaceIndex.rawValue))

        renderEncoder.setFragmentBytes(&cameraComponent.viewSpace, length: MemoryLayout<simd_float4x4>.stride, index: Int(ssaoPassViewSpaceIndex.rawValue))

        // ssao properties
        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.radius,
            length: MemoryLayout<Float>.stride,
            index: Int(ssaoPassRadiusIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.bias,
            length: MemoryLayout<Float>.stride,
            index: Int(ssaoPassBiasIndex.rawValue)
        )

//        renderEncoder.setFragmentBytes(
//            &SSAOParams.shared.intensity,
//            length: MemoryLayout<Float>.stride,
//            index: Int(ssaoPassIntensityIndex.rawValue)
//        )

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.enabled,
            length: MemoryLayout<Bool>.stride,
            index: Int(ssaoPassEnabledIndex.rawValue)
        )
        // set the draw command

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    static let ssaoBlurExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let ssaoBlurPipeline = PipelineManager.shared.renderPipelinesByType[.ssaoBlur] else {
            handleError(.pipelineStateNulled, "ssaoBlurPipeline is nil")
            return
        }

        if !ssaoBlurPipeline.success {
            handleError(.pipelineStateNulled, ssaoBlurPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoBlurRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO Blur render pass descriptor not initialized")
            return
        }

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.ssaoBlurRenderPassDescriptor.depthAttachment.loadAction = .clear
        renderInfo.ssaoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = .load

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "SSAO Blur Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Blur Pass"

        renderEncoder.pushDebugGroup("SSAO Blur Pass")

        renderEncoder.setRenderPipelineState(ssaoBlurPipeline.pipelineState!)
        // renderEncoder.setDepthStencilState(ssaoBlurPipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // pass ssao resources
        renderEncoder.setFragmentTexture(textureResources.ssaoTexture, index: 0)

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.enabled,
            length: MemoryLayout<Bool>.stride,
            index: 0
        )
        // set the draw command

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Optimized SSAO Execution with Quality Tiers

    public static let ssaoOptimizedExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        // Skip SSAO entirely if disabled
        if !SSAOParams.shared.enabled {
            return
        }

        let quality = SSAOParams.shared.quality
        let startTime = CACurrentMediaTime()

        // Execute based on quality tier
        if quality.resolutionScale < 1.0 {
            // Low-res path: SSAO -> Blur (bilateral or simple) -> Upsample
            ssaoLowResExecution(commandBuffer)

            if quality.useBilateralBlur {
                ssaoBilateralBlurExecution(commandBuffer)
            } else {
                ssaoSimpleBlurExecution(commandBuffer)
            }

            ssaoUpsampleExecution(commandBuffer)
        } else {
            // Full-res path: SSAO -> Blur
            ssaoExecution(commandBuffer)

            if quality.useBilateralBlur {
                ssaoBilateralBlurFullResExecution(commandBuffer)
            } else {
                ssaoBlurExecution(commandBuffer)
            }
        }

        // Record timing
        commandBuffer.addCompletedHandler { _ in
            /*
             let endTime = CACurrentMediaTime()
             let elapsed = (endTime - startTime) * 1000.0 // ms

             SSAOParams.shared.lastSSAOTime = elapsed
             SSAOParams.shared.frameCount += 1

             // Rolling average over 60 frames
             let alpha = 1.0 / min(Double(SSAOParams.shared.frameCount), 60.0)
             SSAOParams.shared.avgSSAOTime = SSAOParams.shared.avgSSAOTime * (1.0 - alpha) + elapsed * alpha

             // Log periodically
             if SSAOParams.shared.frameCount % 60 == 0 {
                 print("🔍 SSAO Performance:")
                 print("   Quality: \(quality)")
                 print("   Resolution: \(quality.resolutionScale)x")
                 print("   Samples: \(quality.sampleCount)")
                 print("   Avg Time: \(String(format: "%.2f", SSAOParams.shared.avgSSAOTime)) ms")
             }
              */
        }
    }

    // MARK: - Low-Resolution SSAO Pass

    private static let ssaoLowResExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }

        guard let ssaoPipeline = PipelineManager.shared.renderPipelinesByType[.ssao] else {
            handleError(.pipelineStateNulled, "ssaoPipeline is nil")
            return
        }

        if !ssaoPipeline.success {
            handleError(.pipelineStateNulled, ssaoPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoLowResRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO low-res render pass descriptor not initialized")
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "SSAO Low-Res Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Low-Res Pass"
        renderEncoder.pushDebugGroup("SSAO Low-Res Pass")

        renderEncoder.setRenderPipelineState(ssaoPipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // G-buffer resources (full resolution)
        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture,
            index: Int(ssaoNormalMapTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture,
            index: Int(ssaoPositionMapTextureIndex.rawValue)
        )

        // SSAO resources
        if let kernelBuffer = bufferResources.ssaoKernelBuffer {
            renderEncoder.setFragmentBuffer(kernelBuffer, offset: 0, index: Int(ssaoPassKernelIndex.rawValue))
        }

        renderEncoder.setFragmentTexture(textureResources.ssaoNoiseTexture, index: Int(ssaoNoiseMapTextureIndex.rawValue))

        let quality = SSAOParams.shared.quality
        var kernelSize = quality.sampleCount
        renderEncoder.setFragmentBytes(&kernelSize, length: MemoryLayout<Int>.stride, index: Int(ssaoPassKernelSizeIndex.rawValue))

        // Use low-res viewport for sampling calculations
        var lowResViewPort = renderInfo.viewPort * quality.resolutionScale
        renderEncoder.setFragmentBytes(&lowResViewPort, length: MemoryLayout<simd_float2>.stride, index: Int(ssaoPassViewPortIndex.rawValue))

        renderEncoder.setFragmentBytes(&renderInfo.perspectiveSpace, length: MemoryLayout<simd_float4x4>.stride, index: Int(ssaoPassPerspectiveSpaceIndex.rawValue))
        renderEncoder.setFragmentBytes(&cameraComponent.viewSpace, length: MemoryLayout<simd_float4x4>.stride, index: Int(ssaoPassViewSpaceIndex.rawValue))

        // SSAO properties
        renderEncoder.setFragmentBytes(&SSAOParams.shared.radius, length: MemoryLayout<Float>.stride, index: Int(ssaoPassRadiusIndex.rawValue))
        renderEncoder.setFragmentBytes(&SSAOParams.shared.bias, length: MemoryLayout<Float>.stride, index: Int(ssaoPassBiasIndex.rawValue))
        renderEncoder.setFragmentBytes(&SSAOParams.shared.enabled, length: MemoryLayout<Bool>.stride, index: Int(ssaoPassEnabledIndex.rawValue))

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Bilateral Blur (Separable, Two-Pass)

    private static let ssaoBilateralBlurExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let bilateralPipeline = PipelineManager.shared.renderPipelinesByType[.ssaoBilateralBlur] else {
            handleError(.pipelineStateNulled, "ssaoBilateralBlur is nil")
            return
        }

        if !bilateralPipeline.success {
            handleError(.pipelineStateNulled, bilateralPipeline.name!)
            return
        }

        // Horizontal pass
        ssaoBilateralBlurPass(
            commandBuffer: commandBuffer,
            pipeline: bilateralPipeline,
            sourceTexture: textureResources.ssaoTextureLowRes!,
            destinationDescriptor: renderInfo.ssaoBlurHorizontalRenderPassDescriptor!,
            direction: simd_float2(1.0, 0.0),
            label: "SSAO Bilateral Blur Horizontal"
        )

        // Vertical pass
        ssaoBilateralBlurPass(
            commandBuffer: commandBuffer,
            pipeline: bilateralPipeline,
            sourceTexture: textureResources.ssaoBlurHorizontal!,
            destinationDescriptor: renderInfo.ssaoBlurVerticalRenderPassDescriptor!,
            direction: simd_float2(0.0, 1.0),
            label: "SSAO Bilateral Blur Vertical"
        )
    }

    private static func ssaoBilateralBlurPass(
        commandBuffer: MTLCommandBuffer,
        pipeline: RenderPipeline,
        sourceTexture: MTLTexture,
        destinationDescriptor: MTLRenderPassDescriptor,
        direction: simd_float2,
        label: String
    ) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: destinationDescriptor) else {
            handleError(.renderPassCreationFailed, label)
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = label
        renderEncoder.pushDebugGroup(label)

        renderEncoder.setRenderPipelineState(pipeline.pipelineState!)
        // renderEncoder.setDepthStencilState(pipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // Bind source SSAO texture and depth
        renderEncoder.setFragmentTexture(sourceTexture, index: 0)
        renderEncoder.setFragmentTexture(textureResources.depthMap, index: 1)

        var blurDirection = direction
        renderEncoder.setFragmentBytes(&blurDirection, length: MemoryLayout<simd_float2>.stride, index: 0)

        var enabled = SSAOParams.shared.enabled
        renderEncoder.setFragmentBytes(&enabled, length: MemoryLayout<Bool>.stride, index: 1)

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Simple Blur (Fast Path)

    private static let ssaoSimpleBlurExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let ssaoBlurPipeline = PipelineManager.shared.renderPipelinesByType[.ssaoBlur] else {
            handleError(.pipelineStateNulled, "ssaoBlurPipeline is nil")
            return
        }

        if !ssaoBlurPipeline.success {
            handleError(.pipelineStateNulled, ssaoBlurPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoBlurVerticalRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO Blur render pass descriptor not initialized")
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "SSAO Blur Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Simple Blur Pass"
        renderEncoder.pushDebugGroup("SSAO Simple Blur Pass")

        renderEncoder.setRenderPipelineState(ssaoBlurPipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(textureResources.ssaoTextureLowRes, index: 0)
        renderEncoder.setFragmentBytes(&SSAOParams.shared.enabled, length: MemoryLayout<Bool>.stride, index: 0)

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Upsample Pass

    private static let ssaoUpsampleExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let upsamplePipeline = PipelineManager.shared.renderPipelinesByType[.ssaoUpsample] else {
            handleError(.pipelineStateNulled, "ssaoUpsample is nil")
            return
        }

        if !upsamplePipeline.success {
            handleError(.pipelineStateNulled, upsamplePipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoUpsampleRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO Upsample render pass descriptor not initialized")
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "SSAO Upsample Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Upsample Pass"
        renderEncoder.pushDebugGroup("SSAO Upsample Pass")

        renderEncoder.setRenderPipelineState(upsamplePipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // Source: low-res blurred SSAO
        renderEncoder.setFragmentTexture(textureResources.ssaoBlurTextureLowRes, index: 0)

        // Reference: full-res depth for edge-aware upsampling
        renderEncoder.setFragmentTexture(textureResources.depthMap, index: 1)

        var useDepthAware = SSAOParams.shared.quality.useDepthAwareUpsample
        renderEncoder.setFragmentBytes(&useDepthAware, length: MemoryLayout<Bool>.stride, index: 0)

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Full-Res Bilateral Blur

    private static let ssaoBilateralBlurFullResExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        // For now, use existing box blur for full-res
        // TODO: Implement dedicated full-res bilateral blur if needed
        ssaoBlurExecution(commandBuffer)
    }

    public static let lightExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let lightPipeline = PipelineManager.shared.renderPipelinesByType[.light] else {
            handleError(.pipelineStateNulled, "lightPipeline is nil")
            return
        }

        if !lightPipeline.success {
            handleError(.pipelineStateNulled, lightPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let renderPassDescriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Deferred render pass descriptor not initialized")
            return
        }
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.deferredRenderPassDescriptor.depthAttachment.loadAction = .clear

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Light Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Light Pass"

        renderEncoder.pushDebugGroup("Light Pass")

        renderEncoder.setRenderPipelineState(lightPipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentBytes(&cameraComponent.localPosition, length: MemoryLayout<simd_float3>.stride, index: Int(lightPassCameraPositionIndex.rawValue))

        renderEncoder.setFragmentBytes(
            &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
            index: Int(lightPassLightOrthoViewMatrixIndex.rawValue)
        )

        // G-Buffer data
        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture, index: Int(lightPassAlbedoTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture, index: Int(lightPassNormalTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture, index: Int(lightPassPositionTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(materialTarget.rawValue)].texture, index: Int(lightPassMaterialTextureIndex.rawValue)
        )

        // SSAO Blur texture
        renderEncoder.setFragmentTexture(textureResources.ssaoBlurTexture, index: Int(lightPassSSAOTextureIndex.rawValue))

        // Compute Lighting
        var lightParams = getDirectionalLightParameters()

        renderEncoder.setFragmentBytes(&lightParams, length: MemoryLayout<LightParameters>.stride, index: Int(lightPassLightParamsIndex.rawValue))

        // shadow map
        renderEncoder.setFragmentTexture(
            textureResources.shadowMap, index: Int(lightPassShadowTextureIndex.rawValue)
        )

        let MAX_POINT_LIGHTS = 1024
        let headerSize = 16
        // Point
        _ = uploadAndBindLights(
            buffer: bufferResources.pointLightBuffer,
            lights: getPointLights(), // [PointLight]
            maxCount: MAX_POINT_LIGHTS,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(lightPassPointLightsIndex.rawValue),
            labelForErrors: "Point Lights"
        )

        // Spot
        _ = uploadAndBindLights(
            buffer: bufferResources.spotLightBuffer,
            lights: getSpotLights(), // [SpotLightUniform] or [SpotLight]
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(lightPassSpotLightsIndex.rawValue),
            labelForErrors: "Spot Lights"
        )

        // Area
        _ = uploadAndBindLights(
            buffer: bufferResources.areaLightBuffer,
            lights: getAreaLights(), // [AreaLightUniform] or [AreaLight]
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(lightPassAreaLightsIndex.rawValue),
            labelForErrors: "Area Lights"
        )

        // LTC Maps for Area Lights
        renderEncoder.setFragmentTexture(textureResources.areaTextureLTCMat, index: Int(lightPassAreaLTCMatTextureIndex.rawValue))

        renderEncoder.setFragmentTexture(textureResources.areaTextureLTCMag, index: Int(lightPassAreaLTCMagTextureIndex.rawValue))

        // ibl
        renderEncoder.setFragmentTexture(
            textureResources.irradianceMap, index: Int(lightPassIBLIrradianceTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.specularMap, index: Int(lightPassIBLSpecularTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.iblBRDFMap, index: Int(lightPassIBLBRDFMapTextureIndex.rawValue)
        )

        var brdfParameters = IBLParamsUniform()
        brdfParameters.applyIBL = applyIBL
        brdfParameters.ambientIntensity = ambientIntensity

        renderEncoder.setFragmentBytes(
            &brdfParameters, length: MemoryLayout<IBLParamsUniform>.stride,
            index: Int(lightPassIBLParamIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &envRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(lightPassIBLRotationAngleIndex.rawValue)
        )

        var isGameMode = gameMode
        renderEncoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.size, index: Int(lightPassGameModeIndex.rawValue))

        var ssaoEnabled = SSAOParams.shared.enabled
        renderEncoder.setFragmentBytes(&ssaoEnabled, length: MemoryLayout<Bool>.size, index: Int(lightPassSSAOEnabledIndex.rawValue))

        // set the draw command

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let preCompositeExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let preCompositePipeline = PipelineManager.shared.renderPipelinesByType[.preComposite] else {
            handleError(.pipelineStateNulled, "preCompositePipeline is nil")
            return
        }

        if !preCompositePipeline.success {
            handleError(.pipelineStateNulled, preCompositePipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.renderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Main render pass descriptor not initialized")
            return
        }

        // set the states for the pipeline

        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        if renderInfo.immersionStyle == .none || renderInfo.immersionStyle == .ar {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        } else {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, Double(getAlphaForImmersionMode()))
        }

        // clear it so that it doesn't have any effect on the final output
        if gameMode == false {
            renderInfo.offscreenRenderPassDescriptor?.depthAttachment.loadAction = .clear
            renderInfo.deferredRenderPassDescriptor?.colorAttachments[0]
                .loadAction = .load

            renderInfo.gizmoRenderPassDescriptor?.colorAttachments[0].loadAction = .load
        } else {
            renderInfo.postProcessRenderPassDescriptor?.depthAttachment.loadAction = .clear
            renderInfo.offscreenRenderPassDescriptor?.depthAttachment.loadAction = .clear
            renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0]
                .loadAction = .load

            renderInfo.gizmoRenderPassDescriptor?.colorAttachments[0].loadAction = .clear
        }

        // Load Gaussian texture so it isn't cleared
        renderInfo.gaussianRenderPassDescriptor?.colorAttachments[0].loadAction = .load

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Pre Composite Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Pre Composite Pass"

        renderEncoder.pushDebugGroup("Pre Composite Pass")

        renderEncoder.setRenderPipelineState(preCompositePipeline.pipelineState!)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(
            renderInfo.environmentRenderPassDescriptor?.colorAttachments[0].texture, index: Int(prePassEnvTextureIndex.rawValue)
        )

        if gameMode == false {
            renderEncoder.setFragmentTexture(
                renderInfo.deferredRenderPassDescriptor?.colorAttachments[0].texture,
                index: Int(prePassFinalTextureIndex.rawValue)
            )

            renderEncoder.setFragmentTexture(
                renderInfo.offscreenRenderPassDescriptor?.depthAttachment.texture, index: Int(prePassDepthTextureIndex.rawValue)
            )
        } else {
            let postProcessColorTexture = renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0].texture
            let finalColorTexture = bypassPostProcessing
                ? (renderInfo.deferredRenderPassDescriptor?.colorAttachments[0].texture ?? postProcessColorTexture)
                : postProcessColorTexture

            renderEncoder.setFragmentTexture(
                finalColorTexture,
                index: Int(prePassFinalTextureIndex.rawValue)
            )

            renderEncoder.setFragmentTexture(
                renderInfo.postProcessRenderPassDescriptor?.depthAttachment.texture, index: Int(prePassDepthTextureIndex.rawValue)
            )
        }

        renderEncoder.setFragmentTexture(renderInfo.gizmoRenderPassDescriptor?.colorAttachments[0].texture, index: Int(prePassGizmoTextureIndex.rawValue))

        // Pass the Gaussian texture
        renderEncoder.setFragmentTexture(
            renderInfo.gaussianRenderPassDescriptor?.colorAttachments[0].texture,
            index: Int(prePassGaussianTextureIndex.rawValue)
        )

        var isGameMode = gameMode
        renderEncoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.stride, index: Int(prePassGizmoBufferIndex.rawValue))

        var isPassthrough = (renderInfo.immersionStyle == UntoldImmersionMode.mixed) ? true : false

        renderEncoder.setFragmentBytes(&isPassthrough, length: MemoryLayout<Bool>.stride, index: Int(prePassPassthroughBufferIndex.rawValue))

        // set the draw command

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let gaussianExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        guard let gaussianPipeline = PipelineManager.shared.renderPipelinesByType[.gaussian] else {
            handleError(.pipelineStateNulled, "Guassian Pipeline is nil")
            return
        }

        if !gaussianPipeline.success {
            handleError(.pipelineStateNulled, gaussianPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let renderPassDescriptor = renderInfo.gaussianRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Gaussian render pass descriptor not initialized")
            return
        }

        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = MTLLoadAction.load // Load existing depth from 3D models

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "Gaussian Pass")
            return
        }

        renderEncoder.label = "Gaussian Pass"

        renderEncoder.pushDebugGroup("Gaussian Pass")

        renderEncoder.setRenderPipelineState(gaussianPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(gaussianPipeline.depthState)

        renderEncoder.setVertexBytes(&renderInfo.viewPort, length: MemoryLayout<simd_float2>.stride, index: Int(gaussianRenderViewPortIndex.rawValue))
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let gaussianId = getComponentId(for: GaussianComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

        for entityId in entities {
            guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
                handleError(.noGaussianComponent, entityId)
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

            // update uniforms
            var gaussianUniform = Uniforms()

            var modelMatrix = simd_mul(worldTransformComponent.space, .identity)

            let viewMatrix: simd_float4x4 = cameraComponent.viewSpace

            let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

            let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

            let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

            let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

            gaussianUniform.modelViewMatrix = modelViewMatrix

            gaussianUniform.normalMatrix = normalMatrix

            gaussianUniform.viewMatrix = viewMatrix

            gaussianUniform.modelMatrix = modelMatrix

            gaussianUniform.cameraPosition = cameraComponent.localPosition

            gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace

            if let gaussianUniformBuffer = gaussianComponent.spaceUniform[renderInfo.currentEye] {
                gaussianUniformBuffer.contents().copyMemory(
                    from: &gaussianUniform, byteCount: MemoryLayout<Uniforms>.stride
                )
            } else {
                handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
                return
            }

            renderEncoder.setVertexBuffer(
                gaussianComponent.spaceUniform[renderInfo.currentEye], offset: 0, index: Int(gaussianRenderUniformIndex.rawValue)
            )

            // bind data here
            renderEncoder.setVertexBuffer(
                gaussianComponent.gaussianSortedIndices,
                offset: 0,
                index: Int(gaussianRenderIndicesIndex.rawValue)
            )

            renderEncoder.setVertexBuffer(gaussianComponent.splatData, offset: 0, index: Int(gaussianRenderSplatIndex.rawValue))

            renderEncoder.drawPrimitives(type: .triangleStrip,
                                         vertexStart: 0,
                                         vertexCount: 4,
                                         instanceCount: Int(gaussianComponent.splatCount))
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static func executePostProcess(
        _ pipeline: RenderPipeline,
        source: MTLTexture,
        destination: MTLTexture,
        customization: @escaping (_ encoder: MTLRenderCommandEncoder) -> Void
    ) -> (MTLCommandBuffer) -> Void {
        { commandBuffer in
            if !pipeline.success {
                handleError(.pipelineStateNulled, "Post Process Pipeline")
                return
            }

            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].texture = destination

            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].storeAction = .store
            renderInfo.postProcessRenderPassDescriptor.depthAttachment.loadAction = .load

            guard let renderPassDescriptor = renderInfo.postProcessRenderPassDescriptor else {
                handleError(.renderPassCreationFailed, "Post-process render pass descriptor not initialized")
                return
            }

            // set your encoder here
            guard
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else {
                handleError(.renderPassCreationFailed, "Post Process \(pipeline.name!) Pass")
                return
            }

            defer {
                // Make sure no matter what we end the encoding at the end of the function
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
            }

            renderEncoder.label = "Post-Processing Pass"

            renderEncoder.pushDebugGroup("Post-Processing")

            renderEncoder.setRenderPipelineState(pipeline.pipelineState!)

            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

            renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

            renderEncoder.setFragmentTexture(source, index: 0)

            // Pass in individual post-process values
            customization(renderEncoder)
            // set the draw command
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: bufferResources.quadIndexBuffer!,
                indexBufferOffset: 0
            )

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        }
    }
}

extension float4x4 {
    init(scale s: SIMD3<Float>) {
        self.init(SIMD4<Float>(s.x, 0, 0, 0),
                  SIMD4<Float>(0, s.y, 0, 0),
                  SIMD4<Float>(0, 0, s.z, 0),
                  SIMD4<Float>(0, 0, 0, 1))
    }
}

@inline(__always)
private func uploadAndBindLights<T>(
    buffer: MTLBuffer?,
    lights: [T],
    maxCount: Int,
    headerSize: Int = 16, // uint4 header
    encoder: MTLRenderCommandEncoder,
    bufferIndex: Int,
    labelForErrors: String
) -> Bool {
    guard let buf = buffer else {
        print("Missing buffer for \(labelForErrors)")
        return false
    }

    // Cap to buffer capacity
    let capped = min(lights.count, maxCount)

    // Write count (UInt32) at offset 0; rest of uint4 padding can remain garbage
    buf.contents().storeBytes(of: UInt32(capped), toByteOffset: 0, as: UInt32.self)

    // Copy array right after header
    let dst = buf.contents().advanced(by: headerSize)
    let nBytes = capped * MemoryLayout<T>.stride

    lights.withUnsafeBytes { raw in
        dst.copyMemory(from: raw.baseAddress!, byteCount: nBytes)
    }

    // Bind
    encoder.setFragmentBuffer(buf, offset: 0, index: bufferIndex)
    return true
}
