//
//  EngineRenderPasses.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

import Foundation
import Metal
import MetalKit

struct PostProcessRenderPasses{
    
    
    
}

func executePostProcess(postProcessPipeline:RenderPipeline, uCommandBuffer:MTLCommandBuffer){

    if(!postProcessPipeline.success){
        handleError(.pipelineStateNulled, "Post Process Pipeline")
        return
    }
    
    
    let renderPassDescriptor=renderInfo.renderPassDescriptor!
    
    //set the states for the pipeline
    renderPassDescriptor.colorAttachments[0].loadAction=MTLLoadAction.load
    renderPassDescriptor.colorAttachments[0].clearColor=MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction=MTLStoreAction.store
    
    //set your encoder here
    guard let renderEncoder=uCommandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)else{
        handleError(.renderPassCreationFailed, "Post Process \(postProcessPipeline.name) Pass")
        return
    }
    
        renderEncoder.label = "Post-Processing Pass"
        
        renderEncoder.pushDebugGroup("Post-Processing")
        
        renderEncoder.setRenderPipelineState(postProcessPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(postProcessPipeline.depthState)
        
        renderEncoder.setVertexBuffer(coreBufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(coreBufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
        
        renderEncoder.setFragmentTexture(renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 0);
        
        //set the draw command
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: 6,
                                            indexType: .uint16,
                                            indexBuffer: coreBufferResources.quadIndexBuffer!,
                                            indexBufferOffset: 0)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    
}
