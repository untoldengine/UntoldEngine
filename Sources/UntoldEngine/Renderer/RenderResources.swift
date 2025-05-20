
//
//  RenderResources.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import MetalKit
import ModelIO
import simd

public struct RenderInfo {
    var perspectiveSpace = simd_float4x4.init(1.0)
    var device: MTLDevice!
    var fence: MTLFence!
    var library: MTLLibrary!
    var commandQueue: MTLCommandQueue!
    var bufferAllocator: MTKMeshBufferAllocator!
    var textureLoader: MTKTextureLoader!
    var renderPassDescriptor: MTLRenderPassDescriptor!
    var offscreenRenderPassDescriptor: MTLRenderPassDescriptor!
    var offscreenPaintLightingRenderPass: MTLRenderPassDescriptor!
    var shadowRenderPassDescriptor: MTLRenderPassDescriptor!
    var iblOffscreenRenderPassDescriptor: MTLRenderPassDescriptor!
    var colorPixelFormat: MTLPixelFormat!
    var depthPixelFormat: MTLPixelFormat!
    var viewPort: simd_float2!
}

public struct RenderPipeline {
    var pipelineState: MTLRenderPipelineState?
    var depthState: MTLDepthStencilState?
    var success: Bool = false
    var name: String?
}

public struct ComputePipeline {
    var pipelineState: MTLComputePipelineState?
    var success: Bool = false
    var name: String?
}

public struct MeshShaderPipeline {
    var depthState: MTLDepthStencilState?
    var pipelineState: MTLRenderPipelineState?
    var passDescriptor: MTLRenderPassDescriptor?
    var uniformSpaceBuffer: MTLBuffer?
    var success: Bool = false
}

public struct BufferResources {
    // Point Lights
    var pointLightBuffer: MTLBuffer?

    // Spot lights
    var spotLightBuffer: MTLBuffer?

    var gridUniforms: MTLBuffer?
    var gridVertexBuffer: MTLBuffer?

    var voxelUniforms: MTLBuffer?

    // composite quad
    var quadVerticesBuffer: MTLBuffer?
    var quadTexCoordsBuffer: MTLBuffer?
    var quadIndexBuffer: MTLBuffer?

    // bounding box
    var boundingBoxBuffer: MTLBuffer?

    // ray tracing uniform
    var rayTracingUniform: MTLBuffer?
    var accumulationBuffer: MTLBuffer?

    // ray model
    var rayModelInstanceBuffer: MTLBuffer?
}

public struct VertexDescriptors {
    var model: MDLVertexDescriptor!
}

public struct TextureResources {
    var shadowMap: MTLTexture?
    var colorMap: MTLTexture?
    var normalMap: MTLTexture?
    var positionMap: MTLTexture?

    var depthMap: MTLTexture?

    // ibl
    var environmentTexture: MTLTexture?
    var irradianceMap: MTLTexture?
    var specularMap: MTLTexture?
    var iblBRDFMap: MTLTexture?

    // raytracing dest texture
    var rayTracingDestTexture: MTLTexture?
    var rayTracingPreviousTexture: MTLTexture?
    var rayTracingRandomTexture: MTLTexture?
    var rayTracingDestTextureArray: MTLTexture?
    var rayTracingAccumTexture: [MTLTexture] = []
}

public struct AccelStructResources {
    var primitiveAccelerationStructures: [MTLAccelerationStructure] = []
    var instanceTransforms: [MTLPackedFloat4x3] = []
    var accelerationStructIndex: [UInt32] = []
    var entityIDIndex: [EntityID] = []
    var instanceAccelerationStructure: MTLAccelerationStructure?
    var instanceBuffer: MTLBuffer?
    var mask: [Int32] = []
}
