
//
//  RenderPasses.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

import CShaderTypes
import Foundation
import Metal
import MetalKit

enum RenderPasses {
    static let gridExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if gridPipeline.success == false {
            handleError(.pipelineStateNulled, gridPipeline.name!)
            return
        }

        // update uniforms
        var gridUniforms = Uniforms()

        let modelMatrix = simd_float4x4.init(1.0)

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
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

        let encoderDescriptor = renderInfo.renderPassDescriptor!
        encoderDescriptor.colorAttachments[0].clearColor = mtkBackgroundColor
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Grid Pass")
            return
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

        renderEncoder.popDebugGroup()

        renderEncoder.endEncoding()
    }

    static let executeEnvironmentPass: (MTLCommandBuffer) -> Void = { commandBuffer in

        if environmentPipeline.success == false {
            handleError(.pipelineStateNulled, environmentPipeline.name!)
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        let encoderDescriptor = renderInfo.renderPassDescriptor!

        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Environment Pass")
            return
        }

        renderEncoder.label = "Environment Pass"

        renderEncoder.pushDebugGroup("Environment Pass")

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.clockwise)

        renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)

        renderEncoder.setDepthStencilState(environmentPipeline.depthState)

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

        renderEncoder.popDebugGroup()

        renderEncoder.endEncoding()
    }

    static let shadowExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if shadowPipeline.success == false {
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }

        shadowSystem.updateViewFromSunPerspective()

        // if shadow has no dir light space matrix then no need to proceed
        guard let dirLight = shadowSystem.dirLightSpaceMatrix else { return }

        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderInfo.shadowRenderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "shadow Pass")

            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
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

                if let modelUniformBuffer = mesh.spaceUniform {
                    modelUniformBuffer.contents().copyMemory(
                        from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride
                    )
                } else {
                    handleError(.bufferAllocationFailed, "Model Uniform buffer")
                    return
                }

                renderEncoder.setVertexBuffer(
                    mesh.spaceUniform, offset: 0, index: Int(shadowPassModelUniform.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(shadowPassModelPositionIndex.rawValue)].buffer,
                    offset: 0, index: Int(shadowPassModelPositionIndex.rawValue)
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

    static let modelExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if modelPipeline.success == false {
            handleError(.pipelineStateNulled, modelPipeline.name!)
            return
        }
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
            handleError(.noActiveCamera)
            return
        }
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(materialTarget.rawValue)].loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(emissiveTarget.rawValue)].loadAction = .clear

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .storeAction = .store

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .storeAction = .store
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .storeAction = .store
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(materialTarget.rawValue)]
            .storeAction = .store
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(emissiveTarget.rawValue)]
            .storeAction = .store

        renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction = .store

        let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor!

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Model Pass")

            return
        }

        renderEncoder.label = "Model Pass"

        renderEncoder.pushDebugGroup("Model Pass")

        renderEncoder.setRenderPipelineState(modelPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(modelPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        // Create a component query for entities with both Transform and Render components

        // Iterate over the entities found by the component query
        for entityId in visibleEntityIds {
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
                    mesh.spaceUniform, offset: 0, index: Int(modelPassFragmentUniformIndex.rawValue)
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
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static let ssaoExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if !ssaoPipeline.success {
            handleError(.pipelineStateNulled, ssaoPipeline.name!)
            return
        }

        let renderPassDescriptor = renderInfo.ssaoRenderPassDescriptor!

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

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        renderEncoder.label = "SSAO Pass"

        renderEncoder.pushDebugGroup("SSAO Pass")

        renderEncoder.setRenderPipelineState(ssaoPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(ssaoPipeline.depthState)
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
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static let ssaoBlurExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if !ssaoBlurPipeline.success {
            handleError(.pipelineStateNulled, ssaoBlurPipeline.name!)
            return
        }

        let renderPassDescriptor = renderInfo.ssaoBlurRenderPassDescriptor!

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

        renderEncoder.label = "SSAO Blur Pass"

        renderEncoder.pushDebugGroup("SSAO Blur Pass")

        renderEncoder.setRenderPipelineState(ssaoBlurPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(ssaoBlurPipeline.depthState)
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
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static let lightExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if !lightPipeline.success {
            handleError(.pipelineStateNulled, lightPipeline.name!)
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        let renderPassDescriptor = renderInfo.deferredRenderPassDescriptor!
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

        // point lights
        /*
         if let pointLightBuffer = bufferResources.pointLightBuffer {

             let headerSize = MemoryLayout<UInt32>.stride * 4
             let MAX_POINT_LIGHTS = 1024

             // Grab lights and cap to buffer capacity
             let src = getPointLights()
             let capped = min(src.count, MAX_POINT_LIGHTS)

             // Write count at offset 0
             pointLightBuffer.contents().storeBytes(of: UInt32(capped), toByteOffset: 0, as: UInt32.self)

             // Copy the contiguous bytes of the array after the header
             let dst = pointLightBuffer.contents().advanced(by: headerSize)

             src.withUnsafeBytes{ raw in
                 let stride = MemoryLayout<PointLightUniform>.stride
                 let nBytes = capped * stride
                 dst.copyMemory(from: raw.baseAddress!, byteCount: nBytes)
             }

             renderEncoder.setFragmentBuffer(
                 pointLightBuffer, offset: 0, index: Int(lightPassPointLightsIndex.rawValue)
             )
         } else {
             handleError(.bufferAllocationFailed, bufferResources.pointLightBuffer!.label!)
             return
         }

         // spot light
         if let spotLightBuffer = bufferResources.spotLightBuffer {

             let headerSize = MemoryLayout<UInt32>.stride * 4
             let MAX_POINT_LIGHTS = 1024

             // Grab lights and cap to buffer capacity
             let src = getSpotLights()
             let capped = min(src.count, MAX_POINT_LIGHTS)

             // Write count at offset 0
             spotLightBuffer.contents().storeBytes(of: UInt32(capped), toByteOffset: 0, as: UInt32.self)

             // Copy the contiguous bytes of the array after the header
             let dst = spotLightBuffer.contents().advanced(by: headerSize)

             src.withUnsafeBytes{ raw in
                 let stride = MemoryLayout<SpotLightUniform>.stride
                 let nBytes = capped * stride
                 dst.copyMemory(from: raw.baseAddress!, byteCount: nBytes)
             }

             renderEncoder.setFragmentBuffer(
                 spotLightBuffer, offset: 0, index: Int(lightPassSpotLightsIndex.rawValue)
             )

         } else {
             handleError(.bufferAllocationFailed, bufferResources.spotLightBuffer!.label!)
             return
         }

         // area light
         if let areaLightBuffer = bufferResources.areaLightBuffer {

             let headerSize = MemoryLayout<UInt32>.stride * 4
             let MAX_POINT_LIGHTS = 1024

             // Grab lights and cap to buffer capacity
             let src = getAreaLights()
             let capped = min(src.count, MAX_POINT_LIGHTS)

             // Write count at offset 0
             areaLightBuffer.contents().storeBytes(of: UInt32(capped), toByteOffset: 0, as: UInt32.self)

             // Copy the contiguous bytes of the array after the header
             let dst = areaLightBuffer.contents().advanced(by: headerSize)

             src.withUnsafeBytes{ raw in
                 let stride = MemoryLayout<AreaLightUniform>.stride
                 let nBytes = capped * stride
                 dst.copyMemory(from: raw.baseAddress!, byteCount: nBytes)
             }

             renderEncoder.setFragmentBuffer(
                 areaLightBuffer, offset: 0, index: Int(lightPassAreaLightsIndex.rawValue)
             )

         } else {
             handleError(.bufferAllocationFailed, bufferResources.areaLightBuffer!.label!)
             return
         }
         */
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

    static let gizmoExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if activeEntity == .invalid {
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

    static let lightVisualPass: (MTLCommandBuffer) -> Void = { commandBuffer in

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
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

    static let compositeExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if !compositePipeline.success {
            handleError(.pipelineStateNulled, compositePipeline.name!)
            return
        }

        let renderPassDescriptor = renderInfo.renderPassDescriptor!

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .clear

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Composite Pass")
            return
        }

        renderEncoder.label = "Composite Pass"

        renderEncoder.pushDebugGroup("Composite Pass")

        renderEncoder.setRenderPipelineState(compositePipeline.pipelineState!)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(
            renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 0
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
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static let preCompositeExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if !preCompositePipeline.success {
            handleError(.pipelineStateNulled, preCompositePipeline.name!)
            return
        }

        let renderPassDescriptor = renderInfo.renderPassDescriptor!

        renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].texture = textureResources.vignetteTexture

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        if gameMode == false {
            renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
            renderInfo.deferredRenderPassDescriptor.colorAttachments[0]
                .loadAction = .load

            renderInfo.gizmoRenderPassDescriptor.colorAttachments[0].loadAction = .load
        } else {
            renderInfo.postProcessRenderPassDescriptor.depthAttachment.loadAction = .load
            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0]
                .loadAction = .load

            renderInfo.gizmoRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        }

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Pre Composite Pass")
            return
        }

        renderEncoder.label = "Pre Composite Pass"

        renderEncoder.pushDebugGroup("Pre Composite Pass")

        renderEncoder.setRenderPipelineState(preCompositePipeline.pipelineState!)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(
            renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 1
        )

        if gameMode == false {
            renderEncoder.setFragmentTexture(
                renderInfo.deferredRenderPassDescriptor.colorAttachments[0].texture,
                index: 0
            )

            renderEncoder.setFragmentTexture(
                renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 2
            )
        } else {
            renderEncoder.setFragmentTexture(
                renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].texture,
                index: 0
            )

            renderEncoder.setFragmentTexture(
                renderInfo.postProcessRenderPassDescriptor.depthAttachment.texture, index: 2
            )
        }

        renderEncoder.setFragmentTexture(renderInfo.gizmoRenderPassDescriptor.colorAttachments[0].texture, index: 3)

        var isGameMode = gameMode
        renderEncoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.size, index: 3)

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

    static let debuggerExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

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

            let renderPassDescriptor = renderInfo.postProcessRenderPassDescriptor!

            // set your encoder here
            guard
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else {
                handleError(.renderPassCreationFailed, "Post Process \(pipeline.name!) Pass")
                return
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
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
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
