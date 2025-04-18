
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
            MTLViewport(originX: 0.0, originY: 0.0, width: 1024, height: 1024, znear: 0.0, zfar: 1.0))

        // send buffer data
        renderEncoder.setVertexBytes(
            &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
            index: Int(shadowPassLightMatrixUniform.rawValue)
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

            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)

                // modelMatrix=simd_mul(usdRotation, modelMatrix)

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

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .storeAction = .store

        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .storeAction = .store
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
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
            index: Int(modelPassLightOrthoViewMatrixIndex.rawValue)
        )

        // Compute Lighting
        var lightParams = getLightParameters()

        renderEncoder.setFragmentBytes(&lightParams, length: MemoryLayout<LightParameters>.stride, index: Int(modelPassLightParamsIndex.rawValue))

        renderEncoder.setFragmentBytes(
            &envRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(modelPassIBLRotationAngleIndex.rawValue)
        )

        // ibl
        renderEncoder.setFragmentTexture(
            textureResources.irradianceMap, index: Int(modelPassIBLIrradianceTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.specularMap, index: Int(modelPassIBLSpecularTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.iblBRDFMap, index: Int(modelPassIBLBRDFMapTextureIndex.rawValue)
        )

        var brdfParameters = IBLParamsUniform()
        brdfParameters.applyIBL = applyIBL
        brdfParameters.ambientIntensity = ambientIntensity

        renderEncoder.setFragmentBytes(
            &brdfParameters, length: MemoryLayout<IBLParamsUniform>.stride,
            index: Int(modelPassIBLParamIndex.rawValue)
        )

        if let pointLightBuffer = bufferResources.pointLightBuffer {
            let pointLightArray = Array(getPointLights())

            pointLightArray.withUnsafeBufferPointer { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return }
                pointLightBuffer.contents().copyMemory(
                    from: baseAddress,
                    byteCount: MemoryLayout<PointLight>.stride * getPointLightCount()
                )
            }

        } else {
            handleError(.bufferAllocationFailed, bufferResources.pointLightBuffer!.label!)
            return
        }

        renderEncoder.setFragmentBuffer(
            bufferResources.pointLightBuffer, offset: 0, index: Int(modelPassPointLightsIndex.rawValue)
        )

        var pointLightCount: Int = getPointLightCount()

        renderEncoder.setFragmentBytes(
            &pointLightCount, length: MemoryLayout<Int>.stride,
            index: Int(modelPassPointLightsCountIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            textureResources.shadowMap, index: Int(modelPassShadowTextureIndex.rawValue)
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

            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)

                // modelMatrix=simd_mul(usdRotation, modelMatrix)

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

                for subMesh in mesh.submeshes {
                    // set base texture
                    renderEncoder.setFragmentTexture(
                        subMesh.material?.baseColor, index: Int(modelPassBaseTextureIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        subMesh.material?.roughness, index: Int(modelPassRoughnessTextureIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        subMesh.material?.metallic, index: Int(modelPassMetallicTextureIndex.rawValue)
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
                        index: Int(modelPassMaterialParameterIndex.rawValue)
                    )

                    var hasNormal: Bool = ((subMesh.material?.normal) != nil)
                    renderEncoder.setFragmentBytes(
                        &hasNormal, length: MemoryLayout<Bool>.stride,
                        index: Int(modelPassHasNormalTextureIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        subMesh.material?.normal, index: Int(modelPassNormalTextureIndex.rawValue)
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

    static let highlightExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

        if activeEntity == .invalid {
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        if geometryPipeline.success == false {
            handleError(.pipelineStateNulled, geometryPipeline.name!)
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
            handleError(.renderPassCreationFailed, "Highlight Pass")

            return
        }

        renderEncoder.label = "Highlight Pass"

        renderEncoder.pushDebugGroup("Highlight Pass")

        renderEncoder.setRenderPipelineState(geometryPipeline.pipelineState!)

        renderEncoder.setDepthStencilState(geometryPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.counterClockwise)

        if let t = scene.get(component: WorldTransformComponent.self, for: activeEntity) {
            renderEncoder.setVertexBuffer(bufferResources.boundingBoxBuffer, offset: 0, index: 0)

            renderEncoder.setVertexBytes(
                &cameraComponent.viewSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 1
            )
            renderEncoder.setVertexBytes(
                &renderInfo.perspectiveSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 2
            )
            renderEncoder.setVertexBytes(
                &t.space, length: MemoryLayout<matrix_float4x4>.stride, index: 3
            )
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

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
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
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture,
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

        let windowWidth: Float = renderInfo.viewPort.x
        let windowHeight: Float = renderInfo.viewPort.y

        var textureArray: [MTLTexture] = []
        if currentDebugSelection == DebugSelection.normalOutput {
            if let colorTexture = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture {
                textureArray.append(colorTexture)
            }
            if let normalTexture = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture {
                textureArray.append(normalTexture)
            }
            if let positionTexture = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture {
                textureArray.append(positionTexture)
            }

        } else if currentDebugSelection == DebugSelection.iblOutput {
            textureArray.append(textureResources.environmentTexture!)
            textureArray.append(textureResources.irradianceMap!)
            textureArray.append(textureResources.specularMap!)
            textureArray.append(textureResources.iblBRDFMap!)
        }

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

        renderEncoder.setFragmentBytes(&currentDebugSelection, length: MemoryLayout<Int>.stride, index: 2)

        for i in 0 ..< 4 {
            var currentViewport: Int = i

            renderEncoder.setVertexBytes(&currentViewport, length: MemoryLayout<Int>.stride, index: 5)

            switch i {
            case 0:
                renderEncoder.setFragmentTexture(textureArray[0], index: 0)
            case 1:
                renderEncoder.setFragmentTexture(textureArray[1], index: 0)
            case 2:
                renderEncoder.setFragmentTexture(textureArray[2], index: 0)
            case 3:

                if currentDebugSelection == .iblOutput {
                    renderEncoder.setFragmentTexture(textureArray[3], index: 0)

                } else if currentDebugSelection == .normalOutput {
                    renderEncoder.setFragmentTexture(
                        renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 1
                    )
                }
            default:
                break
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
        { commandBuffer in

            if !pipeline.success {
                handleError(.pipelineStateNulled, "Post Process Pipeline")
                return
            }

            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
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
                renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
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
        { commandBuffer in

            if !pipeline.success {
                handleError(.pipelineStateNulled, "Tone-mapping Pipeline")
                return
            }

            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
                .loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
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
                renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
                    .texture, index: Int(toneMapPassColorTextureIndex.rawValue)
            )

            renderEncoder.setFragmentBytes(
                &toneMapOperator, length: MemoryLayout<Int>.stride,
                index: Int(toneMapPassToneMappingIndex.rawValue)
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
