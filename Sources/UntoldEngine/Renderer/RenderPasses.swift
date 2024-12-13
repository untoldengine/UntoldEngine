
//
//  RenderPasses.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

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

        var viewMatrix: simd_float4x4 = camera.viewSpace
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

        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
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
            bufferResources.gridVertexBuffer, offset: 0, index: Int(GridPassBufferIndices.gridPassPositionIndex.rawValue)
        )

        renderEncoder.setVertexBuffer(
            bufferResources.gridUniforms, offset: 0, index: Int(GridPassBufferIndices.gridPassUniformIndex.rawValue)
        )

        renderEncoder.setFragmentBuffer(
            bufferResources.gridUniforms, offset: 0, index: Int(GridPassBufferIndices.gridPassUniformIndex.rawValue)
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
        environmentConstants.viewMatrix = camera.viewSpace

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
            index: Int(EnvironmentPassBufferIndices.envPassConstantIndex.rawValue)
        )

        renderEncoder.setVertexBytes(
            &envRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(EnvironmentPassBufferIndices.envPassRotationAngleIndex.rawValue)
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

        renderEncoder.label = "Shadow Pass"
        renderEncoder.pushDebugGroup("Shadow Pass")
        renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(shadowPipeline.depthState!)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setDepthBias(0.005, slopeScale: 1.0, clamp: 1.0)
        renderEncoder.setViewport(
            MTLViewport(originX: 0.0, originY: 0.0, width: 1024, height: 1024, znear: 0.0, zfar: 1.0))

        // send buffer data
        renderEncoder.setVertexBytes(
            &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
            index: Int(ShadowBufferIndices.shadowModelLightMatrixUniform.rawValue)
        )

        // need to send light ortho view matrix

        // send info for each entity that conforms to shadows

        // Create a component query for entities with both Transform and Render components
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

        // Iterate over the entities found by the component query
        for entityId in entities {
            
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
                handleError(.noRenderComponent, entityId)
                continue
            }
            
            guard let transformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                handleError(.noWorldTransformComponent, entityId)
                continue
            }
            
            for mesh in renderComponent.mesh{
                // update uniforms
                var modelUniforms = Uniforms()
                
                var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)
                
                // modelMatrix=simd_mul(usdRotation, modelMatrix)
                
                let viewMatrix: simd_float4x4 = camera.viewSpace
                
                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                
                let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)
                
                let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse
                
                let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose
                
                modelUniforms.modelViewMatrix = modelViewMatrix
                
                modelUniforms.normalMatrix = normalMatrix
                
                modelUniforms.viewMatrix = viewMatrix
                
                modelUniforms.modelMatrix = modelMatrix
                
                modelUniforms.cameraPosition = camera.localPosition
                
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
                    mesh.spaceUniform, offset: 0, index: Int(ShadowBufferIndices.shadowModelUniform.rawValue)
                )

                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].buffer,
                    offset: 0, index: Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)
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

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
            .loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
            .loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
            .loadAction = .clear

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
            .storeAction = .store

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
            .storeAction = .store
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
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

        renderEncoder.setVertexBytes(
            &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
            index: Int(ModelPassBufferIndices.modelPassLightOrthoViewMatrixIndex.rawValue)
        )

        var lightDirection = simd_float3(0.0, 1.0, 0.0)
        var lightIntensity: Float = 0.0
        var lightColor = simd_float3(0.0, 0.0, 0.0)
        if let directionalLightID = lightingSystem.dirLight.keys.first,
           let directionalLight: DirectionalLight = lightingSystem.getDirectionalLight(
               entityID: directionalLightID)
        {
            lightDirection = directionalLight.direction
            lightIntensity = directionalLight.intensity
            lightColor = directionalLight.color
        }

        renderEncoder.setVertexBytes(
            &lightDirection, length: MemoryLayout<simd_float3>.stride,
            index: Int(ModelPassBufferIndices.modelPassLightDirectionIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &lightDirection, length: MemoryLayout<simd_float3>.stride,
            index: Int(ModelPassBufferIndices.modelPassLightDirectionIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &lightIntensity, length: MemoryLayout<Float>.stride,
            index: Int(ModelPassBufferIndices.modelPassLightIntensityIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &lightColor, length: MemoryLayout<simd_float3>.stride,
            index: Int(ModelPassBufferIndices.modelPassLightDirectionColorIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &envRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(ModelPassBufferIndices.modelPassIBLRotationAngleIndex.rawValue)
        )

        // ibl
        renderEncoder.setFragmentTexture(
            textureResources.irradianceMap, index: Int(ModelPassBufferIndices.modelIBLIrradianceTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.specularMap, index: Int(ModelPassBufferIndices.modelIBLSpecularTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.iblBRDFMap, index: Int(ModelPassBufferIndices.modelIBLBRDFMapTextureIndex.rawValue)
        )

        var brdfParameters = BRDFSelectionUniform()
        brdfParameters.applyIBL = applyIBL
        brdfParameters.brdfSelection = 0
        brdfParameters.ndfSelection = 0
        brdfParameters.ambientIntensity = ambientIntensity
        brdfParameters.gsSelection = 0

        renderEncoder.setFragmentBytes(
            &brdfParameters, length: MemoryLayout<BRDFSelectionUniform>.stride,
            index: Int(ModelPassBufferIndices.modelPassBRDFIndex.rawValue)
        )

        if let pointLightBuffer = bufferResources.pointLightBuffer {
            // if lightingSystem.currentPointLightCount != lightingSystem.pointLight.count {
            let pointLightArray = Array(lightingSystem.pointLight.values)

            pointLightArray.withUnsafeBufferPointer { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return }
                pointLightBuffer.contents().copyMemory(
                    from: baseAddress,
                    byteCount: MemoryLayout<PointLight>.stride * lightingSystem.pointLight.count
                )
            }

            // lightingSystem.currentPointLightCount=lightingSystem.pointLight.count
            // }

        } else {
            handleError(.bufferAllocationFailed, bufferResources.pointLightBuffer!.label!)
            return
        }

        renderEncoder.setFragmentBuffer(
            bufferResources.pointLightBuffer, offset: 0, index: Int(ModelPassBufferIndices.modelPassPointLightsIndex.rawValue)
        )

        var pointLightCount: Int = lightingSystem.pointLight.count

        renderEncoder.setFragmentBytes(
            &pointLightCount, length: MemoryLayout<Int>.stride,
            index: Int(ModelPassBufferIndices.modelPassPointLightsCountIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            textureResources.shadowMap, index: Int(ModelPassBufferIndices.shadowTextureIndex.rawValue)
        )

        // Create a component query for entities with both Transform and Render components

        let transformId = getComponentId(for: WorldTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

        // Iterate over the entities found by the component query
        for entityId in entities {
            
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
                handleError(.noRenderComponent, entityId)
                continue
            }
            
            guard let transformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                handleError(.noWorldTransformComponent, entityId)
                continue
            }
            
            for mesh in renderComponent.mesh{
                // update uniforms
                var modelUniforms = Uniforms()
                
                var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)
                
                // modelMatrix=simd_mul(usdRotation, modelMatrix)
                
                let viewMatrix: simd_float4x4 = camera.viewSpace
                
                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                
                let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)
                
                let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse
                
                let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose
                
                modelUniforms.modelViewMatrix = modelViewMatrix
                
                modelUniforms.normalMatrix = normalMatrix
                
                modelUniforms.viewMatrix = viewMatrix
                
                modelUniforms.modelMatrix = modelMatrix
                
                modelUniforms.cameraPosition = camera.localPosition
                
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
                    mesh.spaceUniform, offset: 0, index: Int(ModelPassBufferIndices.modelPassUniformIndex.rawValue)
                )
                
                renderEncoder.setFragmentBuffer(
                    mesh.spaceUniform, offset: 0, index: Int(ModelPassBufferIndices.modelPassUniformIndex.rawValue)
                )
                
                // check if it has skeleton component
                var hasArmature = false
                
                if let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) {
                    
                    hasArmature = true
                    
                }
                
                renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(ModelPassBufferIndices.modelPassHasArmature.rawValue))
                
                
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)].buffer,
                    offset: 0, index: Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)
                )
                
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)].buffer,
                    offset: 0, index: Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)
                )
                
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)].buffer, offset: 0,
                    index: Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)
                )
                
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)].buffer,
                    offset: 0, index: Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)
                )
                
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ModelPassBufferIndices.modelPassJointIdIndex.rawValue)].buffer,
                    offset: 0, index: Int(ModelPassBufferIndices.modelPassJointIdIndex.rawValue)
                )
                
                renderEncoder.setVertexBuffer(
                    mesh.metalKitMesh.vertexBuffers[Int(ModelPassBufferIndices.modelPassJointWeightsIndex.rawValue)].buffer,
                    offset: 0, index: Int(ModelPassBufferIndices.modelPassJointWeightsIndex.rawValue)
                )
                
                renderEncoder.setVertexBuffer(mesh.skin?.jointTransformsBuffer, offset: 0, index: Int(ModelPassBufferIndices.modelPassJointMatrixIndex.rawValue))
                
                for subMesh in mesh.submeshes {
                    // set base texture
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.baseColor, index: Int(ModelPassBufferIndices.modelBaseTextureIndex.rawValue)
                    )
                    
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.roughness, index: Int(ModelPassBufferIndices.modelRoughnessTextureIndex.rawValue)
                    )
                    
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.metallic, index: Int(ModelPassBufferIndices.modelMetallicTextureIndex.rawValue)
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
                    
                    materialParameters.hasTexture = simd_int4(
                        Int32(subMesh.material!.hasBaseMap == true ? 1 : 0),
                        Int32(subMesh.material!.hasRoughMap == true ? 1 : 0),
                        Int32(subMesh.material!.hasMetalMap == true ? 1 : 0),
                        0
                    )
                    
                    renderEncoder.setFragmentBytes(
                        &materialParameters, length: MemoryLayout<MaterialParametersUniform>.stride,
                        index: Int(ModelPassBufferIndices.modelDisneyParameterIndex.rawValue)
                    )
                    
                    var hasNormal: Bool = ((subMesh.material?.normal) != nil)
                    renderEncoder.setFragmentBytes(
                        &hasNormal, length: MemoryLayout<Bool>.stride,
                        index: Int(ModelPassBufferIndices.modelHasNormalTextureIndex.rawValue)
                    )
                    
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.normal, index: Int(ModelPassBufferIndices.modelNormalTextureIndex.rawValue)
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

    static let highlightExecution: (MTLCommandBuffer) -> Void = { _ in

        // if selectedModel == false {
        //   return
        // }
        //
        // if geometryPipeline.success == false {
        //   handleError(.pipelineStateNulled, geometryPipeline.name!)
        //   return
        // }
        //
        // renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
        //   .loadAction = .load
        // renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
        //   .loadAction = .load
        // renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
        //   .loadAction = .load
        //
        // renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
        //
        // let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor!
        //
        // guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        // else {
        //
        //   handleError(.renderPassCreationFailed, "Highlight Pass")
        //
        //   return
        // }
        //
        // renderEncoder.label = "Highlight Pass"
        //
        // renderEncoder.pushDebugGroup("Highlight Pass")
        //
        // renderEncoder.setRenderPipelineState(geometryPipeline.pipelineState!)
        //
        // renderEncoder.setDepthStencilState(geometryPipeline.depthState)
        //
        // renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        //
        // renderEncoder.setCullMode(.back)
        //
        // renderEncoder.setFrontFacing(.counterClockwise)
        //
        // if let t = scene.get(component: Transform.self, for: activeEntity) {
        //
        //   renderEncoder.setVertexBuffer(bufferResources.boundingBoxBuffer, offset: 0, index: 0)
        //
        //   renderEncoder.setVertexBytes(
        //     &camera.viewSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 1)
        //   renderEncoder.setVertexBytes(
        //     &renderInfo.perspectiveSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 2)
        //   renderEncoder.setVertexBytes(
        //     &t.localSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 3)
        //   renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: boundingBoxVertexCount)
        //
        // }
        //
        // renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        // renderEncoder.popDebugGroup()
        // renderEncoder.endEncoding()
        //
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

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
            .loadAction = .load

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
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].texture,
            index: 0
        )

        renderEncoder.setFragmentTexture(
            renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 1
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 2
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

    static let debuggerExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if !debuggerPipeline.success {
            handleError(.pipelineStateNulled, debuggerPipeline.name!)
            return
        }

        let renderPassDescriptor = renderInfo.renderPassDescriptor!

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].loadAction = MTLLoadAction.load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
            .loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
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

        let windowWidth: Float = renderInfo.viewPort.x
        let windowHeight: Float = renderInfo.viewPort.y

        // Define viewports
        var viewPortsArray: [MTLViewport] = [
            MTLViewport(
                originX: 0, originY: 0, width: Double(windowWidth) / 2, height: Double(windowHeight) / 2,
                znear: 0.0, zfar: 1.0
            ),
            MTLViewport(
                originX: Double(windowWidth) / 2, originY: 0, width: Double(windowWidth) / 2,
                height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0
            ),
            MTLViewport(
                originX: 0, originY: Double(windowHeight) / 2, width: Double(windowWidth) / 2,
                height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0
            ),
            MTLViewport(
                originX: Double(windowWidth) / 2, originY: Double(windowHeight) / 2,
                width: Double(windowWidth) / 2, height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0
            ),
        ]

        // Define scissor rects
        var scissorRectsArray: [MTLScissorRect] = [
            MTLScissorRect(x: 0, y: 0, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
            MTLScissorRect(
                x: Int(windowWidth) / 2, y: 0, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2
            ),
            MTLScissorRect(
                x: 0, y: Int(windowHeight) / 2, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2
            ),
            MTLScissorRect(
                x: Int(windowWidth) / 2, y: Int(windowHeight) / 2, width: Int(windowWidth) / 2,
                height: Int(windowHeight) / 2
            ),
        ]

        renderEncoder.setViewports(viewPortsArray)
        renderEncoder.setScissorRects(scissorRectsArray)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        for i in 0 ..< 4 {
            var currentViewport: Int = i

            renderEncoder.setVertexBytes(&currentViewport, length: MemoryLayout<Int>.stride, index: 5)

            if i == 0 {
                renderEncoder.setFragmentTexture(
                    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
                        .texture, index: 0
                )
            } else if i == 1 {
                renderEncoder.setFragmentTexture(
                    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
                        .texture, index: 0
                )
            } else if i == 2 {
                renderEncoder.setFragmentTexture(
                    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
                        .texture, index: 0
                )
            } else if i == 3 {
                renderEncoder.setFragmentTexture(
                    renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 1
                )
            }

            // set the draw command

            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: bufferResources.quadIndexBuffer!,
                indexBufferOffset: 0
            )
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    static func executePostProcess(_ pipeline: RenderPipeline) -> (MTLCommandBuffer) -> Void {
        return { commandBuffer in

            if !pipeline.success {
                handleError(.pipelineStateNulled, "Post Process Pipeline")
                return
            }

            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
                .loadAction = .load

            renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load

            let renderPassDescriptor = renderInfo.offscreenRenderPassDescriptor!

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

            renderEncoder.setFragmentTexture(
                renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
                    .texture, index: 0
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
    }

    static func executeTonemapPass(_ pipeline: RenderPipeline) -> (MTLCommandBuffer) -> Void {
        return { commandBuffer in

            if !pipeline.success {
                handleError(.pipelineStateNulled, "Tone-mapping Pipeline")
                return
            }

            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
                .loadAction = .load

            renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load

            let renderPassDescriptor = renderInfo.offscreenRenderPassDescriptor!

            // set your encoder here
            guard
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else {
                handleError(.renderPassCreationFailed, "Tonemapping \(pipeline.name!) Pass")
                return
            }

            renderEncoder.label = "Tone-mapping Pass"

            renderEncoder.pushDebugGroup("Tone-mapping Pass")

            renderEncoder.setRenderPipelineState(pipeline.pipelineState!)

            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

            renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

            renderEncoder.setFragmentTexture(
                renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)]
                    .texture, index: Int(ToneMapPassBufferIndices.toneMapPassColorTextureIndex.rawValue)
            )

            renderEncoder.setFragmentBytes(
                &toneMapOperator, length: MemoryLayout<Int>.stride,
                index: Int(ToneMapPassBufferIndices.toneMapPassToneMappingIndex.rawValue)
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
    }
}
