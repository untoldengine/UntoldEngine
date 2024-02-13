//
//  CommonRenderPasses.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

import Foundation
import Metal
import MetalKit

struct CoreRenderPasses{
    
    static let gridExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
        
        if gridPipeline.success == false{
            handleError(.pipelineStateNulled, gridPipeline.name!)
            return
        }
        
        //update uniforms
        var gridUniforms=Uniforms()
        
        let modelMatrix = simd_float4x4.init(1.0)
        
        var viewMatrix:simd_float4x4 = camera.viewSpace
        viewMatrix=viewMatrix.inverse
        let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)
        
        gridUniforms.modelViewMatrix=modelViewMatrix
        gridUniforms.viewMatrix=viewMatrix
        
        //Note, the perspective projection space has to be inverted to create the infinite grid
        gridUniforms.projectionMatrix=renderInfo.perspectiveSpace.inverse
        
        if let gridUniformBuffer=coreBufferResources.gridUniforms{
            gridUniformBuffer.contents().copyMemory(from: &gridUniforms, byteCount: MemoryLayout<Uniforms>.stride)
        }else{
            handleError(.bufferAllocationFailed, coreBufferResources.gridUniforms!.label!)
            return
        }
        
        //create the encoder
        
        let encoderDescriptor=renderInfo.renderPassDescriptor!
        
        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store;
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear;
        
        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)else{
            
            handleError(.renderPassCreationFailed, "Grid Pass")
            return
        }
        
        renderEncoder.label = "Grid Pass"
        
        renderEncoder.pushDebugGroup("Grid Pass")
        
        renderEncoder.setRenderPipelineState(gridPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(gridPipeline.depthState)
        
        //send the uniforms
        renderEncoder.setVertexBuffer(coreBufferResources.gridVertexBuffer, offset: 0, index: 0)
        
        renderEncoder.setVertexBuffer(coreBufferResources.gridUniforms, offset: 0, index: BufferIndices.gridUniform.rawValue)
        
        renderEncoder.setFragmentBuffer(coreBufferResources.gridUniforms, offset: 0, index: BufferIndices.gridUniform.rawValue)
        
        //send buffer data
        
        renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
    }
    
    static let shadowExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
        
        if shadowPipeline.success == false{
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }
        
        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.shadowRenderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "shadow Pass")
            
            return
        }
        
        
        renderEncoder.label="Shadow Pass"
        renderEncoder.pushDebugGroup("Shadow Pass")
        renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(shadowPipeline.depthState!)
        
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        
        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.1)
        renderEncoder.setViewport(MTLViewport(originX: 0.0, originY: 0.0, width: 1024, height: 1024, znear: 0.0, zfar: 1.0))
        
        
        //send buffer data
        renderEncoder.setVertexBytes(&lightingSystem.dirLight.orthoViewMatrix, length: MemoryLayout<simd_float4x4>.stride, index: Int(shadowVoxelLightMatrixUniform.rawValue))
        
        //need to send light ortho view matrix
        
        //send info for each entity that conforms to shadows
        // Create a component query for entities with both Transform and Render components
        let componentQuery = ComponentQuery<TransformAndRenderChecker>(scene: scene)
        
        // Iterate over the entities found by the component query
        for entityId in componentQuery {
            
            //update uniforms
            var voxelUniforms=Uniforms()
            
            if let transform = scene.get(component: Transform.self, for: entityId) {
                
                var modelMatrix = transform.localSpace
                                
                let viewMatrix:simd_float4x4 = camera.viewSpace
                
                let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)
                
                let upperModelMatrix:matrix_float3x3=matrix3x3_upper_left(modelMatrix)
                
                let inverseUpperModelMatrix:matrix_float3x3=upperModelMatrix.inverse
                let normalMatrix:matrix_float3x3=inverseUpperModelMatrix.transpose
                
                voxelUniforms.modelViewMatrix=modelViewMatrix
                voxelUniforms.normalMatrix=normalMatrix
                voxelUniforms.viewMatrix=viewMatrix
                voxelUniforms.modelMatrix=modelMatrix
                voxelUniforms.cameraPosition=camera.localPosition
                voxelUniforms.projectionMatrix=renderInfo.perspectiveSpace
                
            }
            
            //rendering component data should go here
            
            //create the encoder
            if let render = scene.get(component: Render.self, for: entityId) {
                
                if render.spaceUniform == nil{
                    render.spaceUniform=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
                }
                
                if let voxelUniformBuffer=render.spaceUniform{
                    voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
                }else{
                    handleError(.bufferAllocationFailed, "Voxel Uniform Buffer")
                    return
                }
                
                guard let assetData:AssetData=entityAssetMap[entityId] else {return}
                
                let assetId:AssetID=assetData.assetId
                
                //send the memory pool data for the entity
                vertexMemoryPool!.setVertexBuffer(renderEncoder, assetId, Int(shadowVoxelOriginIndex.rawValue))
                
                renderEncoder.setVertexBuffer(render.spaceUniform, offset: 0, index: Int(shadowVoxelUniform.rawValue))
                
                renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: assetData.indexCount, indexType: MTLIndexType.uint32, indexBuffer: indicesMemoryPool!.getBuffer(), indexBufferOffset: assetData.indexOffset)
                
            }
        }
        
        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
    }

    
    static let voxelExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
        
        if voxelPipeline.success == false{
            handleError(.pipelineStateNulled, voxelPipeline.name!)
            return
        }
        
        
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].loadAction = .clear
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].loadAction = .clear
        
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].storeAction = .store
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].storeAction = .store
        
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction = .store
        
        let encoderDescriptor=renderInfo.offscreenRenderPassDescriptor!
        
        
        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)else{
            
            handleError(.renderPassCreationFailed, "Voxel Pass")
            
            return
        }
        
        renderEncoder.label = "Voxel Pass"
        
        renderEncoder.pushDebugGroup("Voxel Pass")
        
        renderEncoder.setRenderPipelineState(voxelPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(voxelPipeline.depthState)
        
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        
        renderEncoder.setCullMode(.back)
        
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setVertexBytes(&lightingSystem.dirLight.orthoViewMatrix, length: MemoryLayout<simd_float4x4>.stride, index: Int(voxelPassLightOrthoViewMatrixIndex.rawValue))
        
        renderEncoder.setFragmentBytes(&lightingSystem.dirLight.direction, length: MemoryLayout<simd_float3>.stride, index: Int(voxelPassLightDirectionIndex.rawValue))
        
        if let pointLightBuffer = coreBufferResources.pointLightBuffer {
            
            if lightingSystem.currentPointLightCount != lightingSystem.pointLight.count {
                
                lightingSystem.pointLight.withUnsafeBufferPointer { bufferPointer in
                    guard let baseAddress = bufferPointer.baseAddress else { return }
                    pointLightBuffer.contents().copyMemory(from: baseAddress, byteCount: MemoryLayout<PointLight>.stride * lightingSystem.pointLight.count)
                }
                
                lightingSystem.currentPointLightCount=lightingSystem.pointLight.count
            }
            
        } else {
            handleError(.bufferAllocationFailed, coreBufferResources.pointLightBuffer!.label!)
            return
        }

        
        renderEncoder.setFragmentBuffer(coreBufferResources.pointLightBuffer, offset: 0, index: Int(voxelPassPointLightsIndex.rawValue))
        
        var pointLightCount:Int = lightingSystem.pointLight.count
        
        renderEncoder.setFragmentBytes(&pointLightCount, length: MemoryLayout<Int>.stride, index: Int(voxelPassPointLightsCountIndex.rawValue))
        
        renderEncoder.setFragmentTexture(coreTextureResources.shadowMap, index: 3)
        
        // Create a component query for entities with both Transform and Render components
        let componentQuery = ComponentQuery<TransformAndRenderChecker>(scene: scene)
        
        
        // Iterate over the entities found by the component query
        for entityId in componentQuery {
            
            //update uniforms
            var voxelUniforms=Uniforms()
            
            if let transform = scene.get(component: Transform.self, for: entityId) {
                
                var modelMatrix = transform.localSpace
                                
                let viewMatrix:simd_float4x4 = camera.viewSpace
                
                let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)
                
                let upperModelMatrix:matrix_float3x3=matrix3x3_upper_left(modelMatrix)
                
                let inverseUpperModelMatrix:matrix_float3x3=upperModelMatrix.inverse
                let normalMatrix:matrix_float3x3=inverseUpperModelMatrix.transpose
                
                voxelUniforms.modelViewMatrix=modelViewMatrix
                voxelUniforms.normalMatrix=normalMatrix
                voxelUniforms.viewMatrix=viewMatrix
                voxelUniforms.modelMatrix=modelMatrix
                voxelUniforms.cameraPosition=camera.localPosition
                voxelUniforms.projectionMatrix=renderInfo.perspectiveSpace
                
            }
            
            //rendering component data should go here
            
            //create the encoder
            if let render = scene.get(component: Render.self, for: entityId) {
                
                if render.spaceUniform == nil{
                    render.spaceUniform=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
                }
                
                if let voxelUniformBuffer=render.spaceUniform{
                    voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
                }else{
                    handleError(.bufferAllocationFailed, "Voxel Uniform buffer")
                    return
                }
                
                guard let assetData:AssetData=entityAssetMap[entityId] else {
                    handleError(.assetDataMissing, entityId)
                    return
                }
                
                let assetId:AssetID=assetData.assetId
                
                //send the memory pool data for the entity
                vertexMemoryPool!.setVertexBuffer(renderEncoder, assetId, Int(voxelPassVerticesIndex.rawValue))
                
                normalMemoryPool!.setVertexBuffer(renderEncoder, assetId, Int(voxelPassNormalIndex.rawValue))
                
                colorMemoryPool!.setVertexBuffer(renderEncoder, assetId, Int(voxelPassColorIndex.rawValue))
                
                roughnessMemoryPool!.setVertexBuffer(renderEncoder, assetId, Int(voxelPassRoughnessIndex.rawValue))
                
                metallicMemoryPool!.setVertexBuffer(renderEncoder, assetId, Int(voxelPassMetallicIndex.rawValue))
                
                renderEncoder.setVertexBuffer(render.spaceUniform, offset: 0, index: Int(voxelPassUniformIndex.rawValue))
                
                renderEncoder.setFragmentBuffer(render.spaceUniform, offset: 0, index: Int(voxelPassUniformIndex.rawValue))
                
                
                renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: assetData.indexCount, indexType: MTLIndexType.uint32, indexBuffer: indicesMemoryPool!.getBuffer(), indexBufferOffset: assetData.indexOffset)
                
            }
        }
        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
    }
    
    static let compositeExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
        
        if(!compositePipeline.success){
            handleError(.pipelineStateNulled, compositePipeline.name!)
            return
        }
            
        let renderPassDescriptor=renderInfo.renderPassDescriptor!
        
        //set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction=MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor=MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction=MTLStoreAction.store
        
        //set your encoder here
        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)else{
            
            handleError(.renderPassCreationFailed, "Composite Pass")
            return
        }
            
            renderEncoder.label = "Composite Pass"
            
            renderEncoder.pushDebugGroup("Composite Pass")
            
            renderEncoder.setRenderPipelineState(compositePipeline.pipelineState!)
            renderEncoder.setDepthStencilState(compositePipeline.depthState)
            
            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        
            renderEncoder.setVertexBuffer(coreBufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(coreBufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
            
            renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture, index: 0);
    
            renderEncoder.setFragmentTexture(renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 1);
            
            //set the draw command
            
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: 6,
                                                indexType: .uint16,
                                                indexBuffer: coreBufferResources.quadIndexBuffer!,
                                                indexBufferOffset: 0)
            
        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
    }
    
    static let debuggerExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
        
        if(!debuggerPipeline.success){
        handleError(.pipelineStateNulled, debuggerPipeline.name!)
        return
        }

        let renderPassDescriptor=renderInfo.renderPassDescriptor!

        //set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction=MTLLoadAction.load
        renderPassDescriptor.colorAttachments[1].loadAction=MTLLoadAction.load
        renderPassDescriptor.colorAttachments[2].loadAction=MTLLoadAction.load
        
        renderPassDescriptor.depthAttachment.loadAction=MTLLoadAction.load
        renderPassDescriptor.depthAttachment.storeAction=MTLStoreAction.store
        
        //set your encoder here
        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)else{

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
        MTLViewport(originX: 0, originY: 0, width: Double(windowWidth) / 2, height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0),
        MTLViewport(originX: Double(windowWidth) / 2, originY: 0, width: Double(windowWidth) / 2, height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0),
        MTLViewport(originX: 0, originY: Double(windowHeight) / 2, width: Double(windowWidth) / 2, height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0),
        MTLViewport(originX: Double(windowWidth) / 2, originY: Double(windowHeight) / 2, width: Double(windowWidth) / 2, height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0)
        ]

        // Define scissor rects
        var scissorRectsArray: [MTLScissorRect] = [
        MTLScissorRect(x: 0, y: 0, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
        MTLScissorRect(x: Int(windowWidth) / 2, y: 0, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
        MTLScissorRect(x: 0, y: Int(windowHeight) / 2, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
        MTLScissorRect(x: Int(windowWidth) / 2, y: Int(windowHeight) / 2, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2)
        ]

        
        renderEncoder.setViewports(viewPortsArray)
        renderEncoder.setScissorRects(scissorRectsArray)

        renderEncoder.setVertexBuffer(coreBufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(coreBufferResources.quadTexCoordsBuffer, offset: 0, index: 1)


        for i in 0..<4{

            var currentViewport:Int=i
            
            renderEncoder.setVertexBytes(&currentViewport, length: MemoryLayout<Int>.stride, index: 5)
                        
            if i==0{
                renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture, index: 0);
            }else if i==1{
                renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture, index: 0);
            }else if i==2{
                renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture, index: 0);
            }else if i==3{
                renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 1);
            }
           

            //set the draw command

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: 6,
                                                indexType: .uint16,
                                                indexBuffer: coreBufferResources.quadIndexBuffer!,
                                                indexBufferOffset: 0)

        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }
}
