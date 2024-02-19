//
//  Components.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import simd
import MetalKit

struct RenderInfo{
    
    var perspectiveSpace=simd_float4x4.init(1.0)
    var device:MTLDevice!
    var fence:MTLFence!
    var library:MTLLibrary!
    var commandQueue: MTLCommandQueue!
    var renderPassDescriptor:MTLRenderPassDescriptor!
    var offscreenRenderPassDescriptor:MTLRenderPassDescriptor!
    var shadowRenderPassDescriptor:MTLRenderPassDescriptor!
    var iblOffscreenRenderPassDescriptor:MTLRenderPassDescriptor!
    var colorPixelFormat:MTLPixelFormat!
    var depthPixelFormat:MTLPixelFormat!
    var viewPort:simd_float2!
    
}



struct VoxelsMemoryPool{
    var vertexBuffer:MTLBuffer? //float
    var normalBuffer:MTLBuffer?
    var indicesBuffer:MTLBuffer? //int
    
    //material property
    var colorBuffer:MTLBuffer?
    var roughnessBuffer:MTLBuffer?
    var metallicBuffer:MTLBuffer?
}

struct RenderPipeline{
    
    var depthState:MTLDepthStencilState?
    var pipelineState:MTLRenderPipelineState?
    var success:Bool=false
    var name:String?
}

struct ComputePipeline{
    
    var pipelineState:MTLComputePipelineState?
    var success:Bool=false
    
}

struct MeshShaderPipeline{
    
    var depthState:MTLDepthStencilState?
    var pipelineState:MTLRenderPipelineState?
    var passDescriptor:MTLRenderPassDescriptor?
    var uniformSpaceBuffer:MTLBuffer?
    var success:Bool=false
}

struct CoreBufferResources{
    //Point Lights
    var pointLightBuffer:MTLBuffer?
    
    var gridUniforms:MTLBuffer?
    var gridVertexBuffer:MTLBuffer?
    
    var voxelUniforms:MTLBuffer?
    
    //composite quad
    var quadVerticesBuffer:MTLBuffer?
    var quadTexCoordsBuffer:MTLBuffer?
    var quadIndexBuffer:MTLBuffer?
}


struct CoreTextureResources{
    
    var shadowMap:MTLTexture?
    var colorMap:MTLTexture?
    var normalMap:MTLTexture?
    var positionMap:MTLTexture?
    var depthMap:MTLTexture?
}






