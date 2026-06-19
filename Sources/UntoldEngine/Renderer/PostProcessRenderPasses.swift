
//
//  PostProcessRenderPasses.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
    renderEncoder.drawIndexedPrimitivesTracked(
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
    guard let iblPrefilterPipeline = PipelineManager.shared.renderPipelinesByType[.iblPreFilter] else {
        handleError(.pipelineStateNulled, "iblPreFilterPipeline is nil")
        return
    }

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
            renderEncoder.drawIndexedPrimitivesTracked(
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

public func executeXRIBLCubePreFilterPass(
    commandBuffer: MTLCommandBuffer,
    environmentCubeTexture: MTLTexture,
    target: RuntimeEnvironmentLightingTextureSet
) -> Bool {
    guard environmentCubeTexture.textureType == .typeCube else {
        Logger.logWarning(message: "[XRLighting] Environment probe texture is not a cube texture")
        return false
    }

    guard let iblPrefilterPipeline = PipelineManager.shared.renderPipelinesByType[.xrIBLCubePreFilter] else {
        handleError(.pipelineStateNulled, "xrIBLCubePreFilterPipeline is nil")
        return false
    }

    guard iblPrefilterPipeline.success,
          let pipelineState = iblPrefilterPipeline.pipelineState
    else {
        return false
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.renderTargetWidth = target.irradianceMap.width
    renderPassDescriptor.renderTargetHeight = target.irradianceMap.height

    renderPassDescriptor.colorAttachments[0].texture = target.irradianceMap
    renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    renderPassDescriptor.colorAttachments[1].texture = target.specularMap
    renderPassDescriptor.colorAttachments[1].loadAction = .dontCare
    renderPassDescriptor.colorAttachments[1].storeAction = .store

    renderPassDescriptor.colorAttachments[2].texture = target.brdfMap
    renderPassDescriptor.colorAttachments[2].loadAction = .dontCare
    renderPassDescriptor.colorAttachments[2].storeAction = .store

    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
        return false
    }

    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.pushDebugGroup("XR IBL Cube Pre-Filter Pass")
    renderEncoder.label = "XR IBL Cube Pre-Filter Pass"
    renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
    renderEncoder.setFragmentTexture(environmentCubeTexture, index: 0)
    renderEncoder.drawIndexedPrimitivesTracked(
        type: .triangle,
        indexCount: 6,
        indexType: .uint16,
        indexBuffer: bufferResources.quadIndexBuffer!,
        indexBufferOffset: 0
    )
    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()

    guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
        return false
    }
    blitEncoder.label = "XR IBL Specular Mipmap Generation"
    blitEncoder.generateMipmaps(for: target.specularMap)
    blitEncoder.endEncoding()

    return true
}
