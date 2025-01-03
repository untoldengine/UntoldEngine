
//
//  PostProcessRenderPasses.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

import Foundation
import Metal
import MetalKit

struct PostProcessRenderPasses {}

func executePostProcess(postProcessPipeline: RenderPipeline, uCommandBuffer: MTLCommandBuffer) {
    if !postProcessPipeline.success {
        handleError(.pipelineStateNulled, "Post Process Pipeline")
        return
    }

    let renderPassDescriptor = renderInfo.renderPassDescriptor!

    // set the states for the pipeline
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

    let pipelineName: String = postProcessPipeline.name!

    // set your encoder here
    guard
        let renderEncoder = uCommandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
        handleError(.renderPassCreationFailed, "Post Process \(pipelineName) Pass")
        return
    }

    renderEncoder.label = "Post-Processing Pass"

    renderEncoder.pushDebugGroup("Post-Processing")

    renderEncoder.setRenderPipelineState(postProcessPipeline.pipelineState!)
    renderEncoder.setDepthStencilState(postProcessPipeline.depthState)

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

    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()
}

func executeIBLPreFilterPass(uCommandBuffer: MTLCommandBuffer, _ envTexture: MTLTexture) {
    if !iblPrefilterPipeline.success {
        return
    }

    if let renderPassDescriptor = renderInfo.iblOffscreenRenderPassDescriptor {
        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        renderPassDescriptor.colorAttachments[1].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[1].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[1].storeAction = MTLStoreAction.store

        renderPassDescriptor.colorAttachments[2].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[2].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[2].storeAction = MTLStoreAction.store

        // set your encoder here
        if let renderEncoder = uCommandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.setRenderPipelineState(iblPrefilterPipeline.pipelineState!)

            renderEncoder.pushDebugGroup("IBL Pre-Filter Pass")
            renderEncoder.label = "IBL Pre-Filter Pass"

            renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

            renderEncoder.setFragmentTexture(envTexture, index: 0)

            // set the draw command
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: bufferResources.quadIndexBuffer!,
                indexBufferOffset: 0
            )

            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }
    }
}
