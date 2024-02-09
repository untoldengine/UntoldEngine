//
//  EditorRenderPasses.swift
//  UntoldEditor
//
//  Created by Harold Serrano on 1/28/24.
//

import Foundation
import Metal
import MetalKit
import Spatial

struct EditorRenderPasses{
    
    static let EditorVoxelExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
        
        if voxelPipeline.success == false{
            handleError(.pipelineStateNulled, voxelPipeline.name!)
            return
        }
        
        //update uniforms
        var voxelUniforms=Uniforms()
        
        var modelMatrix = simd_float4x4.init(1.0)
        modelMatrix.columns.3.x = modelOffset.x
        modelMatrix.columns.3.y = modelOffset.y
        modelMatrix.columns.3.z = modelOffset.z
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
        
        
        if let voxelUniformBuffer=editorBufferResources.voxelUniforms{
            voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
        }else{
            handleError(.bufferAllocationFailed, "Voxel Uniform")
        }
        
        //create the encoder

        let encoderDescriptor=renderInfo.renderPassDescriptor!
        
        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store;
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load;
        
        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)else{
            handleError(.renderPassCreationFailed, "Editor Voxel Pass")
            return
        }
            
            renderEncoder.label = "Voxel Editor Pass"
            
            renderEncoder.pushDebugGroup("Voxel Editor Pass")
            
            renderEncoder.setRenderPipelineState(voxelPipeline.pipelineState!)
            renderEncoder.setDepthStencilState(voxelPipeline.depthState)
            
            renderEncoder.setCullMode(.back)
        
            renderEncoder.setFrontFacing(.counterClockwise)
            //send the uniforms
            renderEncoder.setVertexBuffer(editorVoxelPool.vertexBuffer, offset: 0, index: Int(voxelPassVerticesIndex.rawValue))
            renderEncoder.setVertexBuffer(editorVoxelPool.normalBuffer, offset: 0, index: Int(voxelPassNormalIndex.rawValue))
            renderEncoder.setVertexBuffer(editorVoxelPool.colorBuffer, offset: 0, index: Int(voxelPassColorIndex.rawValue))
            renderEncoder.setVertexBuffer(editorVoxelPool.roughnessBuffer, offset: 0, index: Int(voxelPassRoughnessIndex.rawValue))
            renderEncoder.setVertexBuffer(editorVoxelPool.metallicBuffer, offset: 0, index: Int(voxelPassMetallicIndex.rawValue))
            
            renderEncoder.setVertexBuffer(editorBufferResources.voxelUniforms, offset: 0, index: Int(voxelPassUniformIndex.rawValue))

            renderEncoder.setFragmentBuffer(editorBufferResources.voxelUniforms, offset: 0, index: Int(voxelPassUniformIndex.rawValue))
            
            if(iblPreFilterComplete){
                renderEncoder.setFragmentTexture(editorTextureResources.irradianceMap, index: 0)
                renderEncoder.setFragmentTexture(editorTextureResources.specularMap, index: 1)
                renderEncoder.setFragmentTexture(editorTextureResources.brdfMap, index: 2)
            }
        
        renderEncoder.setFragmentBytes(&lightingSystem.dirLight.direction, length: MemoryLayout<simd_float3>.stride, index: Int(voxelPassLightDirectionIndex.rawValue))
            
            renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: editorVoxelPool.indicesBuffer!.length/MemoryLayout<UInt32>.stride, indexType: MTLIndexType.uint32, indexBuffer: editorVoxelPool.indicesBuffer!, indexBufferOffset: 0)
            
            
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
    }
    
    
    static let EditorGhostVoxelExecution: (MTLCommandBuffer) -> Void = {commandBuffer in
    
        if ghostVoxelPipeline.success == false{
            handleError(.pipelineStateNulled, ghostVoxelPipeline.name!)
            return
        }
        
        //update uniforms
        var voxelUniforms=Uniforms()
        
        var modelMatrix = simd_float4x4.init(1.0)
        
        modelMatrix=matrix4x4Scale(voxelNeighborScale.x,
                                   voxelNeighborScale.y,
                                   voxelNeighborScale.z)*modelMatrix
        
        let origin=voxelNeighborOrigin*2*scale+modelOffset
        
        modelMatrix.columns.3=simd_float4(origin.x,origin.y,origin.z,1.0)
        
        let viewMatrix:simd_float4x4 = camera.viewSpace
        
        let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)

        voxelUniforms.modelViewMatrix=modelViewMatrix
        voxelUniforms.viewMatrix=viewMatrix
        voxelUniforms.projectionMatrix=renderInfo.perspectiveSpace
        
        
        if let voxelUniformBuffer=editorBufferResources.ghostVoxelUniforms{
            voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
        }else{
            handleError(.bufferAllocationFailed, "Ghost Voxel Uniform")
        }
        
        //create the encoder

        let encoderDescriptor=renderInfo.renderPassDescriptor!
        
        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store;
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load;

        guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)else{
            handleError(.renderPassCreationFailed, "Ghost Voxel Pass")
            return
        }
            
            renderEncoder.label = "Voxel Ghost Pass"
            
            renderEncoder.pushDebugGroup("Voxel Ghost Pass")
            
            renderEncoder.setRenderPipelineState(ghostVoxelPipeline.pipelineState!)
            renderEncoder.setDepthStencilState(ghostVoxelPipeline.depthState)

            //send the uniforms
            renderEncoder.setVertexBuffer(editorBufferResources.ghostVoxelBuffer, offset: 0, index: BufferIndices.voxelVertices.rawValue)
            
            renderEncoder.setVertexBuffer(editorBufferResources.ghostVoxelUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)

            renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.line, indexCount: editorBufferResources.ghostVoxelIndicesBuffer!.length*4/MemoryLayout<simd_int4>.stride, indexType: MTLIndexType.uint32, indexBuffer: editorBufferResources.ghostVoxelIndicesBuffer!, indexBufferOffset: 0)
            
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        
    }
    
}

func executeIBLPreFilterPass(uCommandBuffer:MTLCommandBuffer){
    
    if(iblPreFilterProcessing == true){
        return
    }
    
    if(!iblPrefilterPipeline.success){
        return
    }

    if let renderPassDescriptor=renderInfo.iblOffscreenRenderPassDescriptor{
        //set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction=MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor=MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction=MTLStoreAction.store
        
        renderPassDescriptor.colorAttachments[1].loadAction=MTLLoadAction.load
        renderPassDescriptor.colorAttachments[1].clearColor=MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[1].storeAction=MTLStoreAction.store
        
        renderPassDescriptor.colorAttachments[2].loadAction=MTLLoadAction.load
        renderPassDescriptor.colorAttachments[2].clearColor=MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[2].storeAction=MTLStoreAction.store
        
        //set your encoder here
        if let renderEncoder=uCommandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor){
            
            renderEncoder.setRenderPipelineState(iblPrefilterPipeline.pipelineState!)
            //renderEncoder.setDepthStencilState(iblPrefilterPipeline.depthState)
            renderEncoder.pushDebugGroup("IBL Pre-Filter Pass")
            renderEncoder.label="IBL Pre-Filter Pass"
            
            renderEncoder.setVertexBuffer(editorBufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(editorBufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
            
            renderEncoder.setFragmentTexture(editorTextureResources.environmentTexture, index: 0);
            
            //set the draw command
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: 6,
                                                indexType: .uint16,
                                                indexBuffer: editorBufferResources.quadIndexBuffer!,
                                                indexBufferOffset: 0)
            
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }
    }
    
}

func executeVoxelBoxIntersection(uCommandBuffer:MTLCommandBuffer,_ box:HighLightBox){
    
    //upate the ray uniform
    let viewMatrix:simd_float4x4 = camera.viewSpace

    var rayUniform=RayUniforms()
    
    rayUniform.rayOrigin=rayOrigin
    rayUniform.rayDirection=rayDirection
    rayUniform.projectionMatrix=renderInfo.perspectiveSpace
    rayUniform.viewMatrix=viewMatrix
    
    editorBufferResources.voxelRayUniform?.contents().copyMemory(from: &rayUniform, byteCount: MemoryLayout<RayUniforms>.stride)
    
    if let computeEncoder:MTLComputeCommandEncoder=uCommandBuffer.makeComputeCommandEncoder(){
        
        computeEncoder.setComputePipelineState(voxelBoxIntersectPipeline.pipelineState!)
        
        //load up data
        computeEncoder.setBuffer(editorVoxelPool.originBuffer, offset: 0, index: Int(voxelInBoxOriginIndex.rawValue))
        computeEncoder.setBuffer(editorVoxelPool.voxelVisible, offset: 0, index: Int(voxelInBoxVisibleIndex.rawValue))
        
        
        let boxOriginBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride,options: [])
        
        if let boxOriginBufferPtr=boxOriginBuffer?.contents().bindMemory(to: simd_float3.self, capacity: 1){
            boxOriginBufferPtr.pointee=box.origin
        }
        
        let boxHalfwidthBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride,options: [])
        
        if let boxHalfwidthBufferPtr=boxHalfwidthBuffer?.contents().bindMemory(to: simd_float3.self, capacity: 1){
            boxHalfwidthBufferPtr.pointee=box.halfwidth
        }
        
        computeEncoder.setBuffer(boxOriginBuffer, offset: 0, index: Int(voxelInBoxOrignIndex.rawValue))
        computeEncoder.setBuffer(boxHalfwidthBuffer, offset: 0, index: Int(voxelInBoxHalfwidthIndex.rawValue))
        computeEncoder.setBuffer(editorBufferResources.boxGuidIntersectionBuffer, offset: 0, index: Int(voxelInBoxInterceptedIndex.rawValue))
        computeEncoder.setBuffer(editorBufferResources.boxGuidIntersectionCountBuffer, offset: 0, index: Int(voxelInBoxCountIndex.rawValue))
        computeEncoder.setBuffer(editorBufferResources.voxelRayUniform, offset: 0, index: Int(voxelInBoxRayIndex.rawValue))
        
        //Calculate the threadgroup size
        
        let threadPerThreadgroup=MTLSizeMake(sizeOfChunk*sizeOfChunk, 1, 1)
        let threadsPerGrid=MTLSizeMake(sizeOfChunk*sizeOfChunk*sizeOfChunk, 1, 1) // one for now
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadPerThreadgroup)
        
        boxOriginBuffer?.setPurgeableState(.empty)
        boxHalfwidthBuffer?.setPurgeableState(.empty)
        computeEncoder.endEncoding()
    }
    
}

func executePlanePass(uCommandBuffer:MTLCommandBuffer){
    
    
    //update uniforms
    var planeUniforms=Uniforms()
    
    var modelMatrix = simd_float4x4.init(1.0)
    modelMatrix.columns.3.x = modelOffset.x-scale
    modelMatrix.columns.3.z = modelOffset.z-scale
    let viewMatrix:simd_float4x4 = camera.viewSpace
    
    let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)

    planeUniforms.modelViewMatrix=modelViewMatrix
    planeUniforms.viewMatrix=viewMatrix
    planeUniforms.projectionMatrix=renderInfo.perspectiveSpace
    
    
    if let voxelUniformBuffer=editorBufferResources.planeUniforms{
        voxelUniformBuffer.contents().copyMemory(from: &planeUniforms, byteCount: MemoryLayout<Uniforms>.stride)
    }else{
        return
    }
    
    //create the encoder

    let encoderDescriptor=renderInfo.renderPassDescriptor!
    
    encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
    encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store;
    encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load;

    if let renderEncoder=uCommandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor){
        
        renderEncoder.setRenderPipelineState(planePipeline.pipelineState!)
        renderEncoder.setDepthStencilState(planePipeline.depthState)

        //send the uniforms
        renderEncoder.setVertexBuffer(editorBufferResources.planeBuffer, offset: 0, index: BufferIndices.voxelVertices.rawValue)
        
        renderEncoder.setVertexBuffer(editorBufferResources.planeUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)

        renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.line, indexCount: editorBufferResources.planeIndicesBuffer!.length*4/MemoryLayout<simd_int4>.stride, indexType: MTLIndexType.uint32, indexBuffer: editorBufferResources.ghostVoxelIndicesBuffer!, indexBufferOffset: 0)
        
        
        renderEncoder.endEncoding()
    }
    
    
}


 func executeEnvironmentPass(_ commandBuffer:MTLCommandBuffer){
     
     if environmentPipeline.success == false{
         handleError(.pipelineStateNulled, "Environment pipeline")
         return
     }
     
     guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.renderPassDescriptor!) else {
         handleError(.renderPassCreationFailed, "Environment Pass")
         return
     }

     renderEncoder.label = "IBL Pass"
     
     renderEncoder.pushDebugGroup("IBL Pass")
     
     renderEncoder.setCullMode(.back)
     
     renderEncoder.setFrontFacing(.clockwise)
     
     renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)
     
     renderEncoder.setDepthStencilState(environmentPipeline.depthState)
     
     var environmentConstants=EnvironmentConstants()
     environmentConstants.modelMatrix = matrix4x4Identity()
     environmentConstants.environmentRotation =  matrix4x4Identity()
     environmentConstants.projectionMatrix = renderInfo.perspectiveSpace
     environmentConstants.viewMatrix = camera.viewSpace
     
     //remove the translational part of the view matrix to make the environment stay "infinitely" far away
     environmentConstants.viewMatrix.columns.3 = simd_float4(0.0,0.0,0.0,1.0)
     
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
             renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
         }
     }

     renderEncoder.setVertexBytes(&environmentConstants, length: MemoryLayout<EnvironmentConstants>.stride, index: 4)
     
     renderEncoder.setFragmentTexture(editorTextureResources.environmentTexture, index: 0)

     for submesh in environmentMesh.submeshes {
         renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                             indexCount: submesh.indexCount,
                                             indexType: submesh.indexType,
                                             indexBuffer: submesh.indexBuffer.buffer,
                                             indexBufferOffset: submesh.indexBuffer.offset)

     }
     
     renderEncoder.popDebugGroup()
     
     renderEncoder.endEncoding()
 }

 func executeEnvironmentVisionPass(_ commandBuffer:MTLCommandBuffer,
                                   _ renderPassDescriptor: MTLRenderPassDescriptor){
     
     if environmentPipeline.success == false{
         handleError(.pipelineStateNulled, "Environment pipeline")
         return
     }
     
     guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.renderPassDescriptor!) else {
         handleError(.renderPassCreationFailed, "Environment Vision Pass")
         return
     }

     renderEncoder.label = "VisionOS Environment Render Encoder"
     
     renderEncoder.pushDebugGroup("VisionOS Environment Render Pass")
     
     //render the environment
     
     renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)
     
     renderEncoder.setDepthStencilState(environmentPipeline.depthState)
     
     var environmentConstants=EnvironmentConstants()
     environmentConstants.modelMatrix = matrix4x4Identity()
     environmentConstants.environmentRotation =  matrix4x4Identity()
     environmentConstants.projectionMatrix = renderInfo.perspectiveSpace
     environmentConstants.viewMatrix = camera.viewSpace
     
     //remove the translational part of the view matrix to make the environment stay "infinitely" far away
     environmentConstants.viewMatrix.columns.3 = simd_float4(0.0,0.0,0.0,1.0)
     
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
             renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
         }
     }

     renderEncoder.setVertexBytes(&environmentConstants, length: MemoryLayout<EnvironmentConstants>.stride, index: 4)
     
     renderEncoder.setFragmentTexture(editorTextureResources.environmentTexture, index: 0)

     for submesh in environmentMesh.submeshes {
         renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                             indexCount: submesh.indexCount,
                                             indexType: submesh.indexType,
                                             indexBuffer: submesh.indexBuffer.buffer,
                                             indexBufferOffset: submesh.indexBuffer.offset)

     }
     renderEncoder.popDebugGroup()
     renderEncoder.endEncoding()
 }

 func executeEditorVoxelVisionPass(_ commandBuffer:MTLCommandBuffer,
                             _ renderPassDescriptor: MTLRenderPassDescriptor){
     
     
     guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.renderPassDescriptor!) else {
         handleError(.renderPassCreationFailed, "Editor Vision Pass")
         return
     }

     renderInfo.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
     renderInfo.renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store;
     renderInfo.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load;
     
     renderEncoder.label = "VisionOS Voxel Render Encoder"
     
     renderEncoder.pushDebugGroup("VisionOS Voxel Render Pass")
     
     //render the voxels
     //update uniforms
     var voxelUniforms=Uniforms()
     
     var modelMatrix = simd_float4x4.init(1.0)
     modelMatrix.columns.3.x = modelOffset.x
     modelMatrix.columns.3.y = modelOffset.y
     modelMatrix.columns.3.z = modelOffset.z
     let viewMatrix:simd_float4x4 = camera.viewSpace
     
     let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)
     
     let upperModelMatrix:matrix_float3x3=matrix3x3_upper_left(modelMatrix)
     
     let inverseUpperModelMatrix:matrix_float3x3=upperModelMatrix.inverse
     let normalMatrix:matrix_float3x3=inverseUpperModelMatrix.transpose
     
     let cameraPosition:simd_float3 = -1.0*simd_float3(camera.viewSpace.columns.3.x,camera.viewSpace.columns.3.y,camera.viewSpace.columns.3.z)
     
     voxelUniforms.modelViewMatrix=modelViewMatrix
     voxelUniforms.normalMatrix=normalMatrix
     voxelUniforms.viewMatrix=viewMatrix
     voxelUniforms.modelMatrix=modelMatrix
     voxelUniforms.cameraPosition=cameraPosition
     voxelUniforms.projectionMatrix=renderInfo.perspectiveSpace
     
     
     if let voxelUniformBuffer=editorBufferResources.voxelUniforms{
         voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
     }else{
         handleError(.bufferAllocationFailed, "Voxel uniforms buffer")
         return
     }
     
     
     renderEncoder.setRenderPipelineState(voxelPipeline.pipelineState!)
     renderEncoder.setDepthStencilState(voxelPipeline.depthState)
     
 //    renderEncoder.setCullMode(.back)
 //    renderEncoder.setFrontFacing(.counterClockwise)
     //send the uniforms
     renderEncoder.setVertexBuffer(editorVoxelPool.vertexBuffer, offset: 0, index: BufferIndices.voxelVertices.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.normalBuffer, offset: 0, index: BufferIndices.voxelNormal.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.colorBuffer, offset: 0, index: BufferIndices.voxelColor.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.roughnessBuffer, offset: 0, index: BufferIndices.voxelRoughness.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.metallicBuffer, offset: 0, index: BufferIndices.voxelMetallic.rawValue)
     
     
     renderEncoder.setVertexBuffer(editorBufferResources.voxelUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)

     renderEncoder.setFragmentBuffer(editorBufferResources.voxelUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)
     
     if(iblPreFilterComplete){
         renderEncoder.setFragmentTexture(editorTextureResources.irradianceMap, index: 0)
         renderEncoder.setFragmentTexture(editorTextureResources.specularMap, index: 1)
         renderEncoder.setFragmentTexture(editorTextureResources.brdfMap, index: 2)
     }
     
     renderEncoder.setFragmentBytes(&lightingSystem.dirLight.direction, length: MemoryLayout<simd_float3>.stride, index: BufferIndices.lightPosition.rawValue)
     
     renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: editorVoxelPool.indicesBuffer!.length/MemoryLayout<UInt32>.stride, indexType: MTLIndexType.uint32, indexBuffer: editorVoxelPool.indicesBuffer!, indexBufferOffset: 0)

     renderEncoder.popDebugGroup()
     
     renderEncoder.endEncoding()
     
//     commandBuffer.addCompletedHandler { [weak lightPosBuffer] _ in
//         lightPosBuffer?.setPurgeableState(.empty)
//     }
     
 }

 func executeCompositeVisionPass(_ commandBuffer:MTLCommandBuffer,
                                 _ renderPassDescriptor: MTLRenderPassDescriptor){
     
     if compositePipeline.success == false{
         handleError(.pipelineStateNulled, compositePipeline.name!)
         return
     }
     
     guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.renderPassDescriptor!) else {
         
         handleError(.renderPassCreationFailed, "Composite Vision Pass")
         return
     }
     
     if(!compositePipeline.success){
         return
     }
     

     //set the states for the pipeline
     renderInfo.renderPassDescriptor!.colorAttachments[0].loadAction=MTLLoadAction.load
     renderInfo.renderPassDescriptor!.colorAttachments[0].clearColor=MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
     renderInfo.renderPassDescriptor!.colorAttachments[0].storeAction=MTLStoreAction.store
     
     //set your encoder here
     renderEncoder.label = "Composite Vision Pass"
     
     renderEncoder.pushDebugGroup("Composite Vision Pass")
         
     renderEncoder.setRenderPipelineState(compositePipeline.pipelineState!)
     renderEncoder.setDepthStencilState(compositePipeline.depthState)
     
     renderEncoder.setVertexBuffer(editorBufferResources.quadVerticesBuffer, offset: 0, index: 0)
     renderEncoder.setVertexBuffer(editorBufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
     
   renderEncoder.setFragmentTexture(renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 0);
     
     //set the draw command
     
     renderEncoder.drawIndexedPrimitives(type: .triangle,
                                         indexCount: 6,
                                         indexType: .uint16,
                                         indexBuffer: editorBufferResources.quadIndexBuffer!,
                                         indexBufferOffset: 0)
     
     renderEncoder.popDebugGroup()
     renderEncoder.endEncoding()
     
 }

 func executeGhostVoxelVisionPass(_ commandBuffer:MTLCommandBuffer,
                                  _ renderPassDescriptor: MTLRenderPassDescriptor){
     
     if ghostVoxelPipeline.success == false{
         handleError(.pipelineStateNulled, ghostVoxelPipeline.name!)
         return
     }
     
     guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.renderPassDescriptor!) else {
         handleError(.renderPassCreationFailed, "Ghost Voxel Pass")
         return
     }
     
     //update uniforms
     var voxelUniforms=Uniforms()
     
     var modelMatrix = simd_float4x4.init(1.0)
     modelMatrix=matrix4x4Scale(voxelNeighborScale.x,voxelNeighborScale.y,voxelNeighborScale.z)*modelMatrix
     modelMatrix.columns.3=simd_float4(voxelNeighborOrigin.x,voxelNeighborOrigin.y,voxelNeighborOrigin.z,1.0)+simd_float4(simd_float3(modelOffset),0.0)
     
     let viewMatrix:simd_float4x4 = camera.viewSpace
     
     let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)

     voxelUniforms.modelViewMatrix=modelViewMatrix
     voxelUniforms.viewMatrix=viewMatrix
     voxelUniforms.projectionMatrix=renderInfo.perspectiveSpace
     
     
     if let voxelUniformBuffer=editorBufferResources.ghostVoxelUniforms{
         voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
     }else{
         handleError(.bufferAllocationFailed, "Ghost Voxel Uniform")
         return
     }
     
     //create the encoder

     renderInfo.renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
     renderInfo.renderPassDescriptor!.colorAttachments[0].storeAction = MTLStoreAction.store;
     renderInfo.renderPassDescriptor!.colorAttachments[0].loadAction = MTLLoadAction.load;

     renderEncoder.label = "Voxel Ghost Vision Pass"
     
     renderEncoder.pushDebugGroup("Voxel Ghost Vision Pass")
     
     renderEncoder.setRenderPipelineState(ghostVoxelPipeline.pipelineState!)
     renderEncoder.setDepthStencilState(ghostVoxelPipeline.depthState)

     //send the uniforms
     renderEncoder.setVertexBuffer(editorBufferResources.ghostVoxelBuffer, offset: 0, index: BufferIndices.voxelVertices.rawValue)
     
     renderEncoder.setVertexBuffer(editorBufferResources.ghostVoxelUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)

     renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.line, indexCount: editorBufferResources.ghostVoxelIndicesBuffer!.length*4/MemoryLayout<simd_int4>.stride, indexType: MTLIndexType.uint32, indexBuffer: editorBufferResources.ghostVoxelIndicesBuffer!, indexBufferOffset: 0)
     
     renderEncoder.popDebugGroup()
     renderEncoder.endEncoding()
     
 }

 func executeVisionOSPipeline(_ commandBuffer:MTLCommandBuffer,
                           _ renderPassDescriptor: MTLRenderPassDescriptor,
                           _ projectionMatrix: ProjectiveTransform3D,
                           _ cameraMatrix: matrix_float4x4,
                           _ index:UInt8){
     
     
     guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.renderPassDescriptor!) else {
         
         handleError(.renderPassCreationFailed, "Vision Pass")
         return
         
     }

     renderEncoder.label = "VisionOS Render Encoder"
     
     renderEncoder.pushDebugGroup("Render Environment")
     
     //render the environment
     
     renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)
     
     renderEncoder.setDepthStencilState(environmentPipeline.depthState)
     
     var environmentConstants=EnvironmentConstants()
     environmentConstants.modelMatrix = matrix4x4Identity()
     environmentConstants.environmentRotation =  matrix4x4Identity()
     environmentConstants.projectionMatrix = renderInfo.perspectiveSpace
     environmentConstants.viewMatrix = camera.viewSpace
     
     //remove the translational part of the view matrix to make the environment stay "infinitely" far away
     environmentConstants.viewMatrix.columns.3 = simd_float4(0.0,0.0,0.0,1.0)
     
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
             renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
         }
     }

     renderEncoder.setVertexBytes(&environmentConstants, length: MemoryLayout<EnvironmentConstants>.stride, index: 4)
     
     renderEncoder.setFragmentTexture(editorTextureResources.environmentTexture, index: 0)

     for submesh in environmentMesh.submeshes {
         renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                             indexCount: submesh.indexCount,
                                             indexType: submesh.indexType,
                                             indexBuffer: submesh.indexBuffer.buffer,
                                             indexBufferOffset: submesh.indexBuffer.offset)

     }
     
     //render the voxels
     //update uniforms
     var voxelUniforms=Uniforms()
     
     var modelMatrix = simd_float4x4.init(1.0)
     modelMatrix.columns.3.x = modelOffset.x
     modelMatrix.columns.3.y = modelOffset.y
     modelMatrix.columns.3.z = modelOffset.z
     let viewMatrix:simd_float4x4 = camera.viewSpace
     
     let modelViewMatrix=simd_mul(viewMatrix,modelMatrix)
     
     let upperModelMatrix:matrix_float3x3=matrix3x3_upper_left(modelMatrix)
     
     let inverseUpperModelMatrix:matrix_float3x3=upperModelMatrix.inverse
     let normalMatrix:matrix_float3x3=inverseUpperModelMatrix.transpose

     voxelUniforms.modelViewMatrix=modelViewMatrix
     voxelUniforms.normalMatrix=normalMatrix
     voxelUniforms.viewMatrix=viewMatrix
     voxelUniforms.modelMatrix=modelMatrix
     voxelUniforms.cameraPosition=simd_float3(camera.viewSpace.columns.3.x,camera.viewSpace.columns.3.y,camera.viewSpace.columns.3.z)
     voxelUniforms.projectionMatrix=renderInfo.perspectiveSpace
     
     
     if let voxelUniformBuffer=editorBufferResources.voxelUniforms{
         voxelUniformBuffer.contents().copyMemory(from: &voxelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
     }else{
         return
     }
     
     
     renderEncoder.setRenderPipelineState(voxelPipeline.pipelineState!)
     renderEncoder.setDepthStencilState(voxelPipeline.depthState)
     
 //    renderEncoder.setCullMode(.back)
 //    renderEncoder.setFrontFacing(.counterClockwise)
     //send the uniforms
     renderEncoder.setVertexBuffer(editorVoxelPool.vertexBuffer, offset: 0, index: BufferIndices.voxelVertices.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.normalBuffer, offset: 0, index: BufferIndices.voxelNormal.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.colorBuffer, offset: 0, index: BufferIndices.voxelColor.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.roughnessBuffer, offset: 0, index: BufferIndices.voxelRoughness.rawValue)
     renderEncoder.setVertexBuffer(editorVoxelPool.metallicBuffer, offset: 0, index: BufferIndices.voxelMetallic.rawValue)
     
     
     renderEncoder.setVertexBuffer(editorBufferResources.voxelUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)

     renderEncoder.setFragmentBuffer(editorBufferResources.voxelUniforms, offset: 0, index: BufferIndices.voxelUniform.rawValue)
     
     if(iblPreFilterComplete){
         renderEncoder.setFragmentTexture(editorTextureResources.irradianceMap, index: 0)
         renderEncoder.setFragmentTexture(editorTextureResources.specularMap, index: 1)
         renderEncoder.setFragmentTexture(editorTextureResources.brdfMap, index: 2)
     }
     
     
     //send buffer data

     renderEncoder.setFragmentBytes(&lightingSystem.dirLight.direction, length: MemoryLayout<simd_float3>.stride, index: BufferIndices.lightPosition.rawValue)
     
     renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: editorVoxelPool.indicesBuffer!.length/MemoryLayout<UInt32>.stride, indexType: MTLIndexType.uint32, indexBuffer: editorVoxelPool.indicesBuffer!, indexBufferOffset: 0)

     renderEncoder.popDebugGroup()
     
     renderEncoder.endEncoding()
     
//     commandBuffer.addCompletedHandler { [weak lightPosBuffer] _ in
//         lightPosBuffer?.setPurgeableState(.empty)
//     }
 }
 
