
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
            
            guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                handleError(.noLocalTransformComponent, entityId)
                continue
            }
            
            if let lightComponent = scene.get(component: LightComponent.self, for: entityId){
                continue
            }
            
            if let gizmoComponent = scene.get(component: GizmoComponent.self, for: entityId){
                continue
            }

            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)

                let scaleMatrix = float4x4(scale: localTransformComponent.scale)
                
                modelMatrix = simd_mul(modelMatrix,scaleMatrix)
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
        var lightParams = getDirectionalLightParameters()

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

        // point lights
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

        // spot light
        if let spotLightBuffer = bufferResources.spotLightBuffer {
            let spotLightArray = Array(getSpotLights())

            spotLightArray.withUnsafeBufferPointer { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return }
                spotLightBuffer.contents().copyMemory(
                    from: baseAddress,
                    byteCount: MemoryLayout<SpotLight>.stride * getSpotLightCount()
                )
            }

        } else {
            handleError(.bufferAllocationFailed, bufferResources.spotLightBuffer!.label!)
            return
        }

        renderEncoder.setFragmentBuffer(
            bufferResources.spotLightBuffer, offset: 0, index: Int(modelPassSpotLightsIndex.rawValue)
        )

        var spotLightCount: Int = getSpotLightCount()

        renderEncoder.setFragmentBytes(
            &spotLightCount, length: MemoryLayout<Int>.stride,
            index: Int(modelPassSpotLightsCountIndex.rawValue)
        )
        
        // area light
        if let areaLightBuffer = bufferResources.areaLightBuffer {
            let areaLightArray = Array(getAreaLights())

            areaLightArray.withUnsafeBufferPointer { bufferPointer in
                guard let baseAddress = bufferPointer.baseAddress else { return }
                areaLightBuffer.contents().copyMemory(
                    from: baseAddress,
                    byteCount: MemoryLayout<AreaLight>.stride * getAreaLightCount()
                )
            }

        } else {
            handleError(.bufferAllocationFailed, bufferResources.areaLightBuffer!.label!)
            return
        }

        renderEncoder.setFragmentBuffer(
            bufferResources.areaLightBuffer, offset: 0, index: Int(modelPassAreaLightsIndex.rawValue)
        )

        var areaLightCount: Int = getAreaLightCount()

        renderEncoder.setFragmentBytes(
            &areaLightCount, length: MemoryLayout<Int>.stride,
            index: Int(modelPassAreaLightsCountIndex.rawValue)
        )
        

        // shadow map
        renderEncoder.setFragmentTexture(
            textureResources.shadowMap, index: Int(modelPassShadowTextureIndex.rawValue)
        )
        
        // LTC Maps for Area Lights
        renderEncoder.setFragmentTexture(textureResources.areaTextureLTCMat, index: Int(modelPassAreaLTCMatTextureIndex.rawValue))
        
        renderEncoder.setFragmentTexture(textureResources.areaTextureLTCMag, index: Int(modelPassAreaLTCMagTextureIndex.rawValue))

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

            guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                handleError(.noWorldTransformComponent, entityId)
                continue
            }
            
            guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                handleError(.noLocalTransformComponent, entityId)
                continue
            }
            
            if hasComponent(entityId: entityId, componentType: GizmoComponent.self){
                continue
            }
            
            // is light?
            var isLight: Bool = hasComponent(entityId: entityId, componentType: LightComponent.self)
            renderEncoder.setFragmentBytes(&isLight, length: MemoryLayout<Bool>.stride, index: Int(modelPassIsLight.rawValue))
            
            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)

                let scaleMatrix = float4x4(scale: localTransformComponent.scale)
                
                modelMatrix = simd_mul(modelMatrix,scaleMatrix)
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
                    materialParameters.emmissive = subMesh.material!.emissiveValue

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
    
    static let gizmoExecution: (MTLCommandBuffer) -> Void = { commandBuffer in
        
        if  gizmoPipeline.success == false {
            handleError(.pipelineStateNulled, gizmoPipeline.name!)
            return
        }
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
            handleError(.noActiveCamera)
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
            handleError(.renderPassCreationFailed, "Gizmo Pass")

            return
        }

        renderEncoder.label = "Gizmo Pass"

        renderEncoder.pushDebugGroup("Gizmo Pass")

        renderEncoder.setRenderPipelineState(gizmoPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(gizmoPipeline.depthState)

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
            
            for mesh in renderComponent.mesh {
                // update uniforms
                var modelUniforms = Uniforms()

                var modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)

                let scaleMatrix = float4x4(scale: localTransformComponent.scale)
                
                modelMatrix = simd_mul(modelMatrix,scaleMatrix)

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
                        index: Int(modelPassMaterialParameterIndex.rawValue)
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

        if let t = scene.get(component: LocalTransformComponent.self, for: activeEntity), scene.get(component: RenderComponent.self, for: activeEntity) != nil {
            renderEncoder.setVertexBytes(
                &cameraComponent.viewSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 1
            )
            renderEncoder.setVertexBytes(
                &renderInfo.perspectiveSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 2
            )
            renderEncoder.setVertexBytes(
                &t.space, length: MemoryLayout<matrix_float4x4>.stride, index: 3
            )

            var scale: Float = 1.2

            renderEncoder.setVertexBytes(&scale, length: MemoryLayout<Float>.stride, index: 4)

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
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[0]
                .loadAction = .load
        } else {
            renderInfo.postProcessRenderPassDescriptor.depthAttachment.loadAction = .load
            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0]
                .loadAction = .load
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
                renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture,
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
        
        var isDepthTexture: Bool = false
        if selectedTextureName == "Depth Texture"{
           isDepthTexture = true
        }
        
        var farnear: simd_float2 = simd_float2(near, far)
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
        self.init(SIMD4<Float>(s.x,   0,   0, 0),
                  SIMD4<Float>(  0, s.y,   0, 0),
                  SIMD4<Float>(  0,   0, s.z, 0),
                  SIMD4<Float>(  0,   0,   0, 1))
    }
}
