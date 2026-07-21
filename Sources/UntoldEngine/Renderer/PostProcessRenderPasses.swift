
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
    guard let iblSpecularPipeline = PipelineManager.shared.renderPipelinesByType[.iblSpecularPreFilter] else {
        handleError(.pipelineStateNulled, "iblSpecularPreFilterPipeline is nil")
        return
    }

    if !iblPrefilterPipeline.success || !iblSpecularPipeline.success {
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

    guard let specularMap = textureResources.specularMap,
          specularMap.mipmapLevelCount > 1,
          let pipelineState = iblSpecularPipeline.pipelineState
    else {
        return
    }

    for mipLevel in 1 ..< specularMap.mipmapLevelCount {
        let mipWidth = max(1, specularMap.width >> mipLevel)
        let mipHeight = max(1, specularMap.height >> mipLevel)
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.renderTargetWidth = mipWidth
        renderPassDescriptor.renderTargetHeight = mipHeight
        renderPassDescriptor.colorAttachments[0].texture = specularMap
        renderPassDescriptor.colorAttachments[0].level = mipLevel
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = uCommandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            continue
        }

        var roughness = Float(mipLevel) / Float(max(specularMap.mipmapLevelCount - 1, 1))
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.pushDebugGroup("IBL Specular Pre-Filter Mip \(mipLevel)")
        renderEncoder.label = "IBL Specular Pre-Filter Mip \(mipLevel)"
        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(envTexture, index: 0)
        renderEncoder.setFragmentBytes(&roughness, length: MemoryLayout<Float>.stride, index: 0)
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
    guard let iblSpecularPipeline = PipelineManager.shared.renderPipelinesByType[.xrIBLCubeSpecularPreFilter] else {
        handleError(.pipelineStateNulled, "xrIBLCubeSpecularPreFilterPipeline is nil")
        return false
    }

    guard iblPrefilterPipeline.success,
          let pipelineState = iblPrefilterPipeline.pipelineState,
          iblSpecularPipeline.success,
          let specularPipelineState = iblSpecularPipeline.pipelineState
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

    for mipLevel in 1 ..< target.specularMap.mipmapLevelCount {
        let mipWidth = max(1, target.specularMap.width >> mipLevel)
        let mipHeight = max(1, target.specularMap.height >> mipLevel)
        let mipRenderPassDescriptor = MTLRenderPassDescriptor()
        mipRenderPassDescriptor.renderTargetWidth = mipWidth
        mipRenderPassDescriptor.renderTargetHeight = mipHeight
        mipRenderPassDescriptor.colorAttachments[0].texture = target.specularMap
        mipRenderPassDescriptor.colorAttachments[0].level = mipLevel
        mipRenderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        mipRenderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let mipEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mipRenderPassDescriptor) else {
            continue
        }

        var roughness = Float(mipLevel) / Float(max(target.specularMap.mipmapLevelCount - 1, 1))
        mipEncoder.setRenderPipelineState(specularPipelineState)
        mipEncoder.pushDebugGroup("XR IBL Cube Specular Pre-Filter Mip \(mipLevel)")
        mipEncoder.label = "XR IBL Cube Specular Pre-Filter Mip \(mipLevel)"
        mipEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        mipEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
        mipEncoder.setFragmentTexture(environmentCubeTexture, index: 0)
        mipEncoder.setFragmentBytes(&roughness, length: MemoryLayout<Float>.stride, index: 0)
        mipEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )
        mipEncoder.popDebugGroup()
        mipEncoder.endEncoding()
    }

    return true
}
